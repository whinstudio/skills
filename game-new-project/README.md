# game-new-project

> Generate a Unity 6 mobile game (Android + iOS) from the terminal with the cmpose
> generator, running on your machine as the cmpose MCP server.

When invoked, the skill asks **only four things** (one at a time), takes the rest
from your request, then generates the project locally, sets up git, builds the
Android APK and the iOS simulator build in the background, and opens Unity.

The generated game: Unity 6, 2D or 3D, a Boot scene, a batch build script for
Android and iOS, and either the showcase (the sample games with every feature on:
save system, UI theme, languages, network, purchases, ads, leaderboards) or a blank
game with the features and modules you ask for.

## Requirements

- [Claude Code](https://code.claude.com)
- The cmpose MCP server, added once (Node.js 20+ and git):

      claude mcp add cmpose -- npx --prefer-offline -y @cmpose/mcp@0.5.2

  then restart Claude Code. Without it the skill stops and prints this command.
- Internet access once, for the first generation (it downloads the pinned template)
- Optional, for the verification and opening:
  - **Unity Hub** with the editor version the template needs (the generator tells it,
    e.g. `6000.3.25f1`) and its **Android** and **iOS Build Support** modules —
    or set `UNITY_EDITOR` to the editor binary
  - **Xcode** (full, with the iOS Simulator SDK) and **CocoaPods** — the iOS simulator build

The skill **degrades gracefully**: missing tools are skipped and reported, never fatal.

## Install

```bash
# from the repo root
ln -s "$PWD/game-new-project" ~/.claude/skills/game-new-project   # recommended
# or: cp -R game-new-project ~/.claude/skills/
```

Start a new Claude Code session and run `/game-new-project`.

## Usage

Invoke the skill and answer four prompts (asked one at a time):

1. **Project name** — letters or digits, starting with a letter (e.g. `SkyHopper`) → the folder,
   the C# namespace and the APK name
2. **App name** — the title on the home screen (e.g. `Sky Hopper`)
3. **Package name** — offered as `com.example.<projectname>`; its second segment becomes the
   company name (`Example`), so the namespace is `Example.SkyHopper`
4. **Output directory** — default `~/StudioProjects` (the project goes to `~/StudioProjects/<project>`)

**Never asked**, taken from your request and shown on the confirmation screen (where
you can change them):

- **template** — `showcase` by default; `blank` when you ask for an empty game or a
  specific set of features
- **render** — `2d` by default; `3d` when you say 3D
- **features and modules** (blank only) — the ones you name; purchases and ads only
  when you ask for them explicitly
- **theme** — a style family that suits the game you describe, or the template default
- **IDs** — the test IDs stay (AdMob test ads, the RevenueCat Test Store key,
  placeholder leaderboard IDs); enter your real IDs before release

Examples:

```text
/game-new-project
"bana bir oyun hazırla"
"Unity oyun projesi oluştur"
"create a 3D Unity game"
"create a blank 2D Unity game with leaderboards and a shop module"
```

After generation:

1. Unity Hub → Add → the project folder; open it with the editor version the generator names.
2. Press Play in the Boot scene, or build with File > Build Profiles.
3. Read the project's `README.md` for signing, the real IDs and the release checklist.

## Configuration — `defaults.json`

| key | default | meaning |
|---|---|---|
| `packagePrefix` | `com.example` | package prefix offered for the package question |
| `outputDir` | `~/StudioProjects` | where projects are created |
| `render` | `2d` | render setup when the request does not say 3D |
| `minSdk` / `iosVersion` | `25` / `15.0` | Android min SDK and iOS deployment target |
| `openUnity` | `true` | open the project in Unity after the builds |
| `autoBuildAndroid` | `true` | build the Android APK after generation |
| `autoBuildIos` | `true` | build for the iOS simulator after generation (macOS + Xcode) |

**Model / effort:** the skill runs on **Sonnet (medium effort)** via `SKILL.md`
frontmatter, and your session model resumes afterward.

## How it works

1. Checks that the cmpose MCP tools (`game_describe`, `game_generate`) are connected; stops with the install command otherwise.
2. `game_describe` → the Unity version, the flags, the name rules, the theme families and the pinned template (no static contract copy).
3. Collect the four fields; validate each against those rules.
4. Confirm with a project tree preview.
5. `game_generate` → the project is written to `<outputDir>/<projectName>`.
6. `scripts/setup.sh` → `git init` + initial commit.
7. `scripts/doctor.sh <unityVersion>` → capabilities → `build-android.sh`, then `build-ios.sh`
   (background, one after the other: a batch build cannot run while Unity has the project open) →
   open Unity. If you want Unity open right away, the builds are skipped.

## Scripts

Every script prints `OK: …`, `SKIP: …` (a missing tool, exit 0) or `FAIL: …` (exit 1).
The builds read the Unity version from `ProjectSettings/ProjectVersion.txt`, skip when the
project is open in Unity (`Temp/UnityLockfile`), stop after `UNITY_BUILD_TIMEOUT` seconds per
step (default 1800) and write their logs to `<project>/Builds/logs/`.

```
game-new-project/
├── SKILL.md              # the flow Claude follows
├── defaults.json         # your preferences
└── scripts/
    ├── doctor.sh         # capabilities JSON: node20, git, unity, androidModule, iosModule, xcode, iosSimSdk, pod
    ├── setup.sh          # git init + initial commit → OK: git
    ├── build-android.sh  # Unity batch BuildAndroid → OK: APK <path> (<size>)
    └── build-ios.sh      # Unity batch BuildIOS (simulator) + pod install + xcodebuild → OK: iOS simulator build
```

## Notes

- Generation is local: no account, no API key, no upload, no rate limit.
- A generated project is only as correct as the pinned template of the installed `@cmpose/mcp`.
- The game is not launched on an emulator or a simulator.
