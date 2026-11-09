---
name: game-smoke
description: Use when a Unity 6 mobile game needs checking on a player build - before saying a visual or UI change is done, after changing a screen or layout, before a release, or when asked for a smoke check, a device check or a screenshot of the game on Android or iOS. Runs in a subagent that does not see this conversation; pass the platform and the screen that changed as the argument.
context: fork
background: false
model: sonnet
effort: medium
argument-hint: "[android|ios] [screen or change to check]"
---

# Game smoke

You run in your own subagent. The session that called you sees only your final report, not your
tool output, and you did not see its conversation. You report; you do not fix. Write only under
`qa/` and `Builds/`.

## The visual rule

**A visual task is not done without a screenshot.**

Evidence is a PNG captured from a device or simulator, then read and retained:

1. **Captured** from a player build running on an Android device or emulator or an iOS simulator,
   with the commands in section 4.
2. **Read**: open the PNG with the Read tool and write down what is on screen.
3. **Retained** in `qa/evidence/<platform>/` and cited by path in the report.

The PNG must show the screen that changed. A launch screenshot proves nothing about a screen three
taps in, so navigate there (section 5, Tap) and capture it.

The device run happens now, in this run. When no device is running, boot an emulator or a simulator
yourself (section 4).
Only a PNG counts: the editor's Game view, its Simulator view, Play mode, a clean compile and
passing tests are not evidence and never appear as visual results in the report.

When no PNG can be produced, the task is not done: the report's `Visual` line says `NOT DONE` and
names the step and the error that blocked it.

A still shows layout, clipping, overflow, alignment, colour and legibility. It does not show timing,
animation feel or audio; list those under `Human checks`.

## Results

- Each check gets one of: `PASS`, `WARN`, `FAIL`, `NOT RUN` (the check could not be carried out; say
  why), `NOT ASSESSED` (the data needed to judge it is missing), `n/a` (does not exist on this platform).
- `NOT RUN` and `NOT ASSESSED` never count as passed.

## 1. Input and project

Caller's request: "$ARGUMENTS"

- `android` or `ios` limits the run to that platform; neither means both. The rest names the screen
  or change to check. The project is the current directory unless the request gives a path.
- `Assets/` and `ProjectSettings/` must both exist. Read the version:

  ```bash
  sed -nE 's/^m_EditorVersion: *([^ ]+).*/\1/p' ProjectSettings/ProjectVersion.txt
  ```

  Not a Unity project, or a version not starting with `6000.`: stop, final message `NOT ASSESSED`
  with the reason, write nothing.
- Editor binary (`$UNITY` below): `$UNITY_EDITOR`, else `/Applications/Unity/Hub/Editor/<version>/Unity.app/Contents/MacOS/Unity`.
- `<run>` is `date +%F`, with `-2`, `-3` appended when `qa/smoke-<run>.md` already exists. Then
  `mkdir -p Builds/logs qa/evidence/android qa/evidence/ios`.
- When `Temp/UnityLockfile` exists the project is open in Unity. Tests, builds and device checks are
  `NOT RUN` ("close Unity and re-run"). Never kill Unity.
- Unity builds can pass ten minutes: run every Unity, build-script and `xcodebuild` command in the background and
  wait for it to exit. One at a time; Unity cannot open a project twice.

## 2. Tests

For EditMode, then PlayMode, exactly as below (no `-quit`; Unity exits by itself):

```bash
rm -f Builds/editmode.xml
"$UNITY" -batchmode -projectPath . -runTests -testPlatform EditMode -testResults Builds/editmode.xml -logFile Builds/logs/editmode.log
grep -m1 '<test-run' Builds/editmode.xml
```

Read `total` and `failed` on that line. `failed` above 0: `FAIL`. `total` 0: `NOT ASSESSED`. No XML:
`FAIL` with the first `error CS` line of the log, or `NOT RUN` with the last log lines when there is none.
A test failure does not stop the run.

## 3. Build

Always build; an older APK or app says nothing about the current code.

With `~/.claude/skills/game-new-project/scripts/` present, run `build-android.sh <projectDir>` and
`build-ios.sh <projectDir>`. They end in `OK:`, `FAIL:` or `SKIP:`. `SKIP:` exits 0 but built nothing:
that is `NOT RUN` with its reason, and that platform's device checks are `NOT RUN`.

Otherwise use the project's build script. `<ns>` is the `namespace` line of
`Assets/Editor/Build/BuildScript.cs`; without that file, Build is `NOT RUN`.

```bash
"$UNITY" -batchmode -nographics -quit -projectPath "$PWD" -buildTarget Android -executeMethod <ns>.BuildScript.BuildAndroid -cmposeOut "$PWD/Builds/game.apk" -logFile Builds/logs/android.log
"$UNITY" -batchmode -nographics -quit -projectPath "$PWD" -buildTarget iOS -executeMethod <ns>.BuildScript.BuildIOS -cmposeOut "$PWD/Builds/ios" -cmposeSimulator -logFile Builds/logs/ios-unity.log
```

Each succeeded when its log has `CMPOSE_BUILD_RESULT` with `result=Succeeded`. For iOS, then in
`Builds/ios` run `pod install` when there is a `Podfile`, and build with `-workspace Unity-iPhone.xcworkspace`
in that case, `-project Unity-iPhone.xcodeproj` otherwise:

```bash
xcodebuild -workspace Unity-iPhone.xcworkspace -scheme Unity-iPhone -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath ../ios-dd CODE_SIGNING_ALLOWED=NO build
```

A failed build is `FAIL`; that platform's device checks are `NOT RUN`.

## 4. Install, launch, capture

The APK is the path in the `OK: APK` line (or the `-cmposeOut` path). The iOS app is
`find Builds/ios-dd/Build/Products/Debug-iphonesimulator -maxdepth 1 -name '*.app'`.

### Android

`adb` and `emulator` are in `platform-tools/` and `emulator/` of `$ANDROID_HOME` (default
`~/Library/Android/sdk`). Every `adb` command names its serial.

```bash
adb devices                                            # take a serial in state "device", emulator-NNNN first
emulator -list-avds                                    # none attached: start one in the background
emulator -avd <name> -no-snapshot-save                 # its serial is the new emulator-NNNN in adb devices
adb -s <serial> wait-for-device
adb -s <serial> shell getprop sys.boot_completed       # repeat until it prints 1
adb -s <serial> shell getprop ro.product.cpu.abilist   # must contain arm64-v8a
```

The APK is IL2CPP ARM64. A device without `arm64-v8a` cannot install it: try another, else Android
device checks are `NOT RUN` with the ABI list. No device can be booted: same, with the command's error.

Package name: the `Android:` value printed by the first command, confirmed after install by `pm path`.
When that is empty or `pm path` prints nothing, use the second command's `package: name='...'`.

```bash
grep -A4 '^  applicationIdentifier:' ProjectSettings/ProjectSettings.asset
$ANDROID_HOME/build-tools/<version>/aapt2 dump badging <apk> | head -n 1
```

```bash
adb -s <serial> uninstall <package>        # emulator only, so first-launch dialogs appear
adb -s <serial> install -r <apk>
adb -s <serial> shell pm path <package>
adb -s <serial> logcat -b crash -c
adb -s <serial> shell monkey -p <package> -c android.intent.category.LAUNCHER 1
adb -s <serial> shell pidof <package>      # after the wait below; empty means it died
adb -s <serial> exec-out screencap -p > qa/evidence/android/<run>-01-launch.png
adb -s <serial> logcat -d -b crash         # any lines for this package are a crash
```

On a physical device skip `uninstall`, and Dialogs is `NOT RUN`.

### iOS

```bash
xcrun simctl list devices available        # a booted iPhone first, else the newest non-SE iPhone
xcrun simctl bootstatus <udid> -b          # boots it and waits
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "<app>/Info.plist"
xcrun simctl uninstall <udid> <bundleId>
xcrun simctl install <udid> "<app>"
xcrun simctl launch <udid> <bundleId>      # prints "<bundleId>: <pid>"
xcrun simctl io <udid> screenshot qa/evidence/ios/<run>-01-launch.png
```

### Both

Wait at least 10 seconds between launch and capture: a shell cannot count frames, and 60 rendered
frames have to come after the splash. Name files `<run>-NN-<what-it-shows>.png`. Confirm each with
`file <path>` (PNG, not empty), then Read it. An install or launch error is `FAIL`.

### Closing, after section 5

```bash
adb -s <serial> shell am force-stop <package>
xcrun simctl terminate <udid> <bundleId>
adb -s <serial> emu kill                   # only an emulator this run started
xcrun simctl shutdown <udid>               # only a simulator this run started
```

## 5. Checks

Run each on each platform, and cite the PNG behind every visual result.

| Check | How | Result |
|---|---|---|
| Screen | Read the launch PNG. A single colour, the splash or the home screen: wait 10 s and capture again, up to 60 s | Still so, or process died, or crash lines: `FAIL`, and the remaining checks are `NOT RUN` |
| Orientation | The `orientation` field of `design/brief.md` against the PNG; judge by which way text and UI read | Mismatch `FAIL`. No file or field: `NOT ASSESSED` |
| Safe area | Text and controls clear of the notch or Dynamic Island, status bar and home indicator. Use a device that has a cutout | Control or text covered: `FAIL`. Android AVD without a cutout: `NOT ASSESSED` |
| Touch targets | Estimate each control's size in the PNG. Android: dp = px x 160 / density, from `adb -s <serial> shell wm density`, minimum 48 dp. iOS: pt = px / 3 (iPhones since the 12, except SE), minimum 44 pt | Primary control below minimum: `FAIL`. Any other: `WARN` |
| Thumb zone | Portrait: primary action in the lower half. Landscape: at the lower left or right | Outside: `WARN` |
| Tap | Android: pick the primary button's centre in PNG pixels, `adb -s <serial> shell input tap <x> <y>`, wait 2 s, capture, compare. No change: retry once with `adb -s <serial> shell input swipe <x> <y> <x> <y> 150`. iOS: `simctl` has no tap command, so this is `NOT RUN` unless this session has a tool that can tap in the Simulator window | Still no change: `FAIL`. Use taps to reach the changed screen; when it cannot be reached, its visual check is `NOT RUN` |
| Back key | Android: `adb -s <serial> shell input keyevent 4`, wait 2 s, `pidof`, capture. iOS: `n/a` | Crash or stuck screen: `FAIL`. Ignored, or quits from gameplay without asking: `WARN` |
| Background and return | Android: note `pidof`, `input keyevent 3`, wait 3 s, the `monkey` launch again, wait 3 s, `pidof`, capture. iOS: `xcrun simctl launch <udid> com.apple.Preferences`, wait 3 s, `xcrun simctl launch <udid> <bundleId>`, compare the printed pids, capture | New pid, crash or black screen: `FAIL` |
| Mute key | Android: `adb -s <serial> shell input keyevent 164`, wait 2 s, `pidof`, capture, send 164 again to restore. Proves only that it survives the key. iOS: no command-line control, `NOT RUN` | Crash or freeze: `FAIL`. Add "silence when muted" to `Human checks` |
| Dialogs | Read the first-launch PNGs for system permission or notification dialogs | Asked before the game has shown why: `WARN`. Blocks the game with no way past: `FAIL`. One you cannot dismiss: capture it, and checks behind it are `NOT RUN` |

Compare before and after captures by reading both PNGs. Do not grant permissions from the command
line; that hides what a player sees.

## 6. Report

Per platform, the first match wins:

1. `FAIL`: any check is `FAIL`.
2. `NOT ASSESSED`: tests, build, launch or the launch PNG is `NOT RUN` or `NOT ASSESSED`.
3. `PASS WITH WARNINGS`: any `WARN`, or any other check `NOT RUN` or `NOT ASSESSED`. Those stay
   listed by name; they are gaps, not passes.
4. `PASS`: every check `PASS` or `n/a`.

Overall is the worse platform, in that order. Write `qa/smoke-<run>.md`, leaving out a platform
that was not requested, and do not commit it:

```markdown
# Smoke <run>

Project: <name> | Unity <version> | Commit <short sha, "+ uncommitted" if dirty> | Changed: <screen or "not named">
Devices: Android <serial, model, API> | iOS <device, runtime>

| Check | Android | iOS |
|---|---|---|
| EditMode tests | PASS (42) | PASS (42) |
| PlayMode tests | NOT ASSESSED (0 tests) | NOT ASSESSED (0 tests) |
| Build | PASS | NOT RUN (no iOS Build Support) |
| Install and launch | PASS | NOT RUN |
| Screen | PASS - qa/evidence/android/<run>-01-launch.png | NOT RUN |
| <one row per other check in section 5> | | |

Verdict: Android NOT ASSESSED | iOS NOT ASSESSED | Overall NOT ASSESSED
Visual: Android DONE - <PNG path>, shows <what> | iOS NOT DONE - <step and error>

## Findings
## Human checks
```

`Visual` is per platform: `DONE` needs a read PNG of the changed screen, or of the launch screen when
no screen was named. One `Findings` entry per `FAIL`, in the [bug-report](references/bug-report.md) format.

Your final message, nothing else: the `Verdict` and `Visual` lines, one line per `FAIL`, `NOT RUN`
or `NOT ASSESSED` check with its reason, and the report path. No raw logs.

## Never

Edit game code, assets, scenes, tests or `ProjectSettings`; commit or push; close an emulator or
simulator this run did not start.
