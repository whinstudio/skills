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
tool output, and you did not see its conversation. If you cannot fork, run this skill's steps
yourself in the current session. You report; you do not fix. Do not edit tracked
project files; reports go under `qa/`, build output under `Builds/`. Unity itself rewrites some
tracked files (for example under `Assets/Settings`) when tests and builds run; that is expected.
Run `git status --short` at the start and list under `Findings` only the files that changed during
the run; leave them, do not revert or commit them.

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
- When `Temp/UnityLockfile` exists the project is open in the Unity editor. Never kill Unity. Stop
  before tests and builds, write no report, and send the final message with `Verdict: NOT ASSESSED`,
  `Visual: NOT DONE - close the Unity editor and run again`, and the `Caller:` line of section 6. A
  build script's `SKIP:` for the same lockfile is the same stop.
- `<run>` is `date +%F`, with `-2`, `-3` appended when `qa/smoke-<run>.md` already exists. Then
  `mkdir -p Builds/logs qa/evidence/android qa/evidence/ios`.
- Unity builds can pass ten minutes: run every Unity, build-script and `xcodebuild` command in the background and
  wait for it to exit. One at a time; Unity cannot open a project twice.

## 2. Tests

EditMode exactly as below (no `-quit`; Unity exits by itself):

```bash
rm -f Builds/editmode.xml
"$UNITY" -batchmode -projectPath . -runTests -testPlatform EditMode -testResults Builds/editmode.xml -logFile Builds/logs/editmode.log
grep -m1 '<test-run' Builds/editmode.xml
```

Then PlayMode: the same commands with `-testPlatform PlayMode`, `Builds/playmode.xml` and `playmode.log`.

For each, read `total` and `failed` on that line. `failed` above 0: `FAIL`. `total` 0: `NOT ASSESSED`. No XML:
`FAIL` with the first `error CS` line of the log, or `NOT RUN` with the last log lines when there is none.
A test failure does not stop the run.

## 3. Build

Always build; an older APK or app says nothing about the current code.

With `~/.claude/skills/game-new-project/scripts/` present, run `build-android.sh <projectDir>` and
`build-ios.sh <projectDir>`. They end in `OK:`, `FAIL:` or `SKIP:`. `SKIP:` exits 0 but built nothing:
that is `NOT RUN` with its reason, and that platform's device checks are `NOT RUN`.

Otherwise use the project's build script. `<ns>` is the full namespace after the
`namespace` keyword in `Assets/Editor/Build/BuildScript.cs`, ending in `.Editor.Build`; without that
file, Build is `NOT RUN`.

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

`ANDROID_HOME` is often unset and `adb`, `emulator` and `aapt2` are often not on `PATH`. Set
`ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"` and call `$ANDROID_HOME/platform-tools/adb`,
`$ANDROID_HOME/emulator/emulator` and `$ANDROID_HOME/build-tools/<version>/aapt2`, where `<version>`
is the newest directory in `$ANDROID_HOME/build-tools` (`ls "$ANDROID_HOME/build-tools" | sort -V | tail -1`).
Below, `adb`, `emulator` and `aapt2` stand for those full paths. Every `adb` command names its serial.

Run every `adb` and `simctl` step with a 60 s limit by prefixing it with
`perl -e 'alarm 60; exec @ARGV' --` (perl ships with macOS; `timeout` does not). It kills the
command after 60 s with exit status 142, and redirects such as `> file` still work, for example
`perl -e 'alarm 60; exec @ARGV' -- xcrun simctl uninstall <udid> <bundleId>`. A capture counts as
an adb step, for example
`perl -e 'alarm 60; exec @ARGV' -- adb -s <serial> exec-out screencap -p > qa/evidence/android/<run>-01-launch.png`.
Below, `adb` and
`xcrun simctl` steps are shown without the prefix. Not the `emulator` or `bootstatus` boot, and not
`wait-for-device`, which you poll instead. A step that hits the limit is retried once; hitting it
again means that device is not usable: try another device (iOS: see below). When no usable device
is left, that platform's device checks are `NOT RUN` with the reason "timeout" (not `FAIL`).

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

`emulator -list-avds` printing nothing means Android is `NOT RUN`, with the report line "create an
arm64 AVD in Android Studio". Do not create one automatically.

Package name: the first command prints one line, `    Android: <package>`, confirmed after install by
`pm path`. `ProjectSettings.asset` has other `Android:` lines, so keep the `sed` range. When the
line is missing or `pm path` prints nothing, use the second command's `package: name='...'`.

```bash
sed -n '/^  applicationIdentifier:/,/^  [^ ]/p' ProjectSettings/ProjectSettings.asset | grep -E '^    Android:'
aapt2 dump badging <apk> | head -n 1
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

An empty PNG (the adb server restarted, or the device went `offline`): run `adb devices`, wait until
the serial is `device` again, and capture again. The wait is bounded, for example 6 tries 5 s apart;
if the serial never reaches `device`, that device is not usable (the `NOT RUN` rule above). The
serial is only ever an `emulator-NNNN`.

```bash
for i in 1 2 3 4 5 6; do adb devices | grep -q "^<serial>[[:space:]]*device$" && break; sleep 5; done
```

On a physical device skip `uninstall`, and Dialogs is `NOT RUN`.

### iOS

Prefer a simulator this run boots. A simulator that is already booted may belong to another session
and may hang. If an `install`, `uninstall` or `launch` on a device you did not start hits the 60 s
limit again after the retry, boot a different available iPhone yourself and use that one; never keep
working on, or shut down, the other session's device. Foldables and other odd models have no known
point scale, so prefer a plain iPhone.

```bash
xcrun simctl list devices available        # a booted iPhone first, else the newest non-SE iPhone
xcrun simctl bootstatus <udid> -b          # boots it and waits
open -a Simulator                          # when a tap tool is available: it needs the Simulator window
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "<app>/Info.plist"
xcrun simctl uninstall <udid> <bundleId>
xcrun simctl install <udid> "<app>"
xcrun simctl launch <udid> <bundleId>      # prints "<bundleId>: <pid>"
xcrun simctl io <udid> screenshot qa/evidence/ios/<run>-01-launch.png
```

A device with several displays (foldables) fails with "Cannot choose between 2 displays". Run
`xcrun simctl io <udid> enumerate`, pick the main display, and pass `--display=<id>` before the
file: `xcrun simctl io <udid> screenshot --display=1 <png>`.

### Both

Wait at least 10 seconds after launch before the first capture. A system tip over the game (such as
Android's "Viewing full screen / Got it") is not a permission dialog: dismiss it with a tap on its
button (Tap row, section 5), capture again and go on. Name files
`<run>-NN-<what-it-shows>.png`. Confirm each with `file <path>` (PNG, not empty), then Read it. An
install or launch error is `FAIL`; a step that only times out (above) is not, it is `NOT RUN`.

The Read tool may show a downscaled PNG, so coordinates seen in it are not device pixels. Before a tap
or a touch-target measurement, read the real size and multiply what you measured by real width /
displayed width. When the displayed width is unknown, work in fractions of the image and multiply
them by the real size.

```bash
sips -g pixelWidth -g pixelHeight <png>
```

### Closing, after section 5

Remember which emulator or simulator this run started. Skip `emu kill` and `simctl shutdown` for any
device this run did not start.

```bash
adb -s <serial> shell am force-stop <package>
xcrun simctl terminate <udid> <bundleId>
adb -s <serial> emu kill
xcrun simctl shutdown <udid>
```

## 5. Checks

Run each on each platform, and cite the PNG behind every visual result.

| Check | How | Result |
|---|---|---|
| Screen | Read the launch PNG. A single colour, the splash or the home screen: poll, capturing every 10 s until the screen changes, for up to 90 s (a heavy first menu can take over 30 s). Do not stop at the first unchanged capture | Still so, or process died, or crash lines: `FAIL`, and the remaining checks are `NOT RUN` |
| Orientation | The `orientation` field of `design/brief.md` against the PNG; judge by which way text and UI read | Mismatch `FAIL`. No file or field: `NOT ASSESSED` |
| Safe area | Text and controls clear of the notch or Dynamic Island, status bar and home indicator. Use a device that has a cutout | Control or text covered: `FAIL`. Android AVD without a cutout: `NOT ASSESSED` |
| Touch targets | Estimate each control's size in real PNG pixels (section 4, Both). Android: dp = px x 160 / density, from `adb -s <serial> shell wm density`, minimum 48 dp. iOS: pt = px / scale, with the scale read from the device (see below); never assume 3. Scale unreadable: the check is `NOT RUN`. Minimum 44 pt | Primary control clearly under the minimum (under 80% of it: 38 dp, 35 pt): `FAIL`. Any other shortfall: `WARN` |
| Thumb zone | Portrait: primary action in the lower half. Landscape: at the lower left or right | Outside: `WARN` |
| Tap | Android: pick the primary button's centre, scaled to real PNG pixels (section 4, Both), `adb -s <serial> shell input tap <x> <y>`, wait 2 s, capture, compare. No change: retry once with `adb -s <serial> shell input swipe <x> <y> <x> <y> 150`. iOS: `simctl` has no tap command (do not invent one). With a tool that can tap in the Simulator window, first run `open -a Simulator`, then tap there; otherwise this is `NOT RUN` | Still no change: `FAIL`. Use taps to reach the changed screen; when it cannot be reached, its visual check is `NOT RUN` |
| Back key | Android: `adb -s <serial> shell input keyevent 4`, wait 2 s, `pidof`, capture. iOS: `n/a` | Crash, or stuck (no response to the next tap, or the pid is gone): `FAIL`. Ignored (the screen is unchanged, the pid is the same and the next tap works), or quits from gameplay without asking: `WARN` |
| Background and return | Android: note `pidof`, `input keyevent 3`, wait 3 s, the `monkey` launch again, wait 3 s, `pidof`, capture. iOS: `xcrun simctl launch <udid> com.apple.Preferences`, wait 3 s, `xcrun simctl launch <udid> <bundleId>`, compare the printed pids, capture | New pid, crash or black screen: `FAIL` |
| Mute key | Android: `adb -s <serial> shell input keyevent 164`, wait 2 s, `pidof`, capture, send 164 again to restore. Proves only that it survives the key. The volume panel can cover part of the screen, so this PNG is not visual evidence of the screen: use a capture taken without it. iOS: no command-line control, `NOT RUN` | Crash or freeze: `FAIL`. Add "silence when muted" to `Human checks` |
| Dialogs | Read the first-launch PNGs for system permission or notification dialogs | Asked before the game has shown why: `WARN`. Blocks the game with no way past: `FAIL`. One you cannot dismiss: capture it, and checks behind it are `NOT RUN` |

iOS point scale: the device's `deviceTypeIdentifier` is in `xcrun simctl list devices -j`; its
`bundlePath` is in `xcrun simctl list devicetypes -j`. Then
`/usr/libexec/PlistBuddy -c 'Print :capabilities:ScreenDimensionsCapability:main-screen-scale' "<bundlePath>/Contents/Resources/capabilities.plist"`
prints the scale (`main-screen-width` and `main-screen-height` beside it are the main display's
pixels). The file or key missing: the scale is unreadable.

Compare before and after captures by reading both PNGs. Do not grant permissions from the command
line; that hides what a player sees.

## 6. Report

Per platform, the first match wins:

1. `FAIL`: any check is `FAIL`.
2. `NOT ASSESSED`: build, launch or the launch PNG is `NOT RUN` or `NOT ASSESSED`. Nothing else can
   give this verdict.
3. `PASS WITH WARNINGS`: any `WARN`, or any other check `NOT RUN` or `NOT ASSESSED`, tests included
   (zero tests stays `NOT ASSESSED` on its own line). Each is named on the `Gaps` line; they are
   gaps, not passes.
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

Verdict: Android PASS WITH WARNINGS | iOS NOT ASSESSED | Overall NOT ASSESSED
Visual: Android DONE - <PNG path>, shows <what> | iOS NOT DONE - <step and error>
Gaps: Android PlayMode tests (0 tests) | iOS PlayMode tests (0 tests)

## Findings
## Human checks
```

`Visual` is per platform: `DONE` needs a read PNG of the changed screen, or of the launch screen when
no screen was named. One `Findings` entry per `FAIL`, in the [bug-report](references/bug-report.md) format.

Your final message, nothing else: the `Verdict` and `Visual` lines, one line per `FAIL`, `NOT RUN`
or `NOT ASSESSED` check with its reason, the report path, and a last line starting `Caller:` with
what the caller may say. No raw logs.

### What the caller may say

The work may be called done only when `Visual` is `DONE` on every requested platform and the overall
verdict is `PASS` or `PASS WITH WARNINGS`. Anything else is reported as not verified, naming the
blocker. If the user cannot wait, the caller says "looks right in the editor, not verified on a
device" and finishes the run afterwards.

## Never

Edit game code, assets, scenes, tests or `ProjectSettings`; commit or push; close an emulator or
simulator this run did not start.
