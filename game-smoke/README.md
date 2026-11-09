# game-smoke

> Check a Unity 6 mobile game on a real player build: tests, Android APK and iOS simulator
> build, launch, screenshots and a short list of mobile checks, with a report per platform.

A visual task is not done without a screenshot. Evidence is a PNG captured from a device or
simulator, then read and retained in the project. The editor's Game view does not count.

The skill runs in a separate Sonnet subagent, reports and does not fix anything.

## Requirements

- [Claude Code](https://code.claude.com)
- **Unity Hub** with the project's editor version and its **Android** and **iOS Build Support**
  modules, or `UNITY_EDITOR` set to the editor binary. The project must be closed in Unity.
- **Android SDK** with `adb`, the emulator, and an **ARM64** device or emulator image (the game is
  IL2CPP ARM64)
- **Xcode** (full, with the iOS Simulator SDK) and **CocoaPods**, for iOS
- Recommended: the [`game-new-project`](../game-new-project) skill, whose scripts do the builds.
  Without it the skill calls the project's `Assets/Editor/Build/BuildScript.cs` directly.

A missing tool is never fatal, and never a pass: what could not run is reported as `NOT RUN` or
`NOT ASSESSED`.

## Install

```bash
# from the repo root
ln -s "$PWD/game-smoke" ~/.claude/skills/game-smoke   # recommended
# or: cp -R game-smoke ~/.claude/skills/
```

## Usage

From the Unity project's folder, name the platform and the screen that changed. Both are optional.

```text
/game-smoke
/game-smoke android
/game-smoke ios the shop screen
"smoke check the main menu on Android"
```

`game-look` and `game-release` call this skill by name.

## What it checks

EditMode and PlayMode tests; the Android and iOS builds; install and launch; that the screen is not
blank; orientation against the `orientation` field of `design/brief.md`; notch and safe area; touch
targets of at least 44 pt / 48 dp; the thumb zone; a tap; the Android back key; going to the
background and returning; the mute key; system dialogs.

Limits:

- iOS simulator touch has no standard command-line tool, so the tap check is `NOT RUN` on iOS unless
  the session has a tool that can tap in the Simulator window.
- The skill cannot hear: whether the game goes silent stays a human check.
- It closes only the emulators and simulators it started.

## Output

- `qa/smoke-<run>.md`: a table per platform and the verdict `PASS`, `PASS WITH WARNINGS`, `FAIL` or
  `NOT ASSESSED`
- `qa/evidence/android/`, `qa/evidence/ios/`: the PNGs the report cites

## License

Adapted and shortened for Unity 6 mobile from Claude Code Game Studios (MIT). See
[LICENSE-UPSTREAM.md](./LICENSE-UPSTREAM.md).
