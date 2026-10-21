---
name: game-new-project
model: sonnet
effort: medium
description: >-
  Scaffold a new Unity 6 mobile game (Android + iOS, 2D or 3D) with the cmpose
  generator, which runs on this machine as the cmpose MCP server (game_describe,
  game_generate). Use whenever the user wants to create / generate / scaffold a new
  game or Unity project — e.g. "bana bir oyun hazırla", "Unity oyun projesi
  oluştur", "3D bir mobil oyun kur", "create a 3D Unity game", "scaffold a 2D
  Unity game with leaderboards". When invoked the skill asks ONLY four fields —
  project name, app name, package, output directory — one at a time; everything
  else (template, render, flags, modules, theme) comes from the request or smart
  defaults and is NEVER asked. Then it generates the project locally, sets up git,
  verifies the Android APK and the iOS simulator build, and opens Unity.
---

# game-new-project

Generate a Unity 6 mobile game with the cmpose generator. It runs on this machine as the cmpose MCP
server (`@cmpose/mcp`, tools `game_describe` and `game_generate`): no account, no API key, no upload.
**Kept short**: ONLY four fields are asked one at a time (project name, app name, package, output
dir); the template, render, flags, modules and theme come from the request and are shown
(changeable) at the confirmation step. Skill directory: `~/.claude/skills/game-new-project/`.

Run scripts with `bash ~/.claude/skills/game-new-project/scripts/<name>.sh`.
There is no static contract copy: the rules are read from `game_describe` at run time.

## 0. MCP check + contract + preferences (silent)
1. **The cmpose MCP server must be connected.** Its tools are `game_describe` and `game_generate`
   (usually listed as `mcp__cmpose__game_describe` / `mcp__cmpose__game_generate`). If they are not
   available in this session, **stop before asking anything** and tell the user, in their language:
   - the generator runs locally as an MCP server; add it once with this command, then restart Claude
     Code (`/exit`, then `claude`) and ask again:

         claude mcp add cmpose -- npx -y @cmpose/mcp@0.7.1

   - it needs Node.js 20+ and git: run `scripts/doctor.sh` and report `node20` and `git` (if it
     cannot run, just say so).
   Never generate any other way (no web API, no copying the template by hand).
2. Read `defaults.json` (prefs).
3. Call `game_describe` once. It is the contract: `unityVersion` (the editor the project needs),
   `template` (the pinned `repo` + `ref`), `defaults` (`templateType`, `render`, `flags`, `minSdk`,
   `iosVersion`), `themes` (`default`, `families` with `id`, `title`, `suits`, `fontPairs`) and
   `contract` (`templateTypes`, `renders`, `flags`, `flagRequires`, `idGroups`, `limits`,
   `reservedNames`, `reservedModuleNames`, `reservedPackagePrefix`).
4. **Pre-fill from the request:** if the user already named a field (project name, game title,
   package, folder), use it as that field's value and skip that question in step 2.

## 1. Auto-defaults — DO NOT ASK these (keep the form short)
- **Template → `showcase`** (the sample games with every flag on). Use `blank` only when the user
  asks for an empty game ("boş", "blank", "sıfırdan", "örnek oyunsuz", "from scratch") or names a
  specific set of flags or modules to start from.
- **Render → `defaults.render`** (`2d`); `3d` when the request says "3D", "3d", "üç boyutlu" or
  "three-dimensional".
- **Flags (blank only)** → the request's wording matched to `contract.flags` (save system, UI theme,
  languages / çoklu dil, network, network inspector, leaderboards / skor tablosu, …). The generator
  adds the required ones (`flagRequires`, e.g. `networkInspector ⇒ network`); never pass flags with
  `showcase`.
  **Turn on `purchases` / `ads` only when the user explicitly asks for in-app purchases / a paywall
  (RevenueCat) or for ads (AdMob).** Never infer them from words like "premium", "subscription",
  "purchases" or "satın alma" alone (a "premium-feeling puzzle game" is not a purchases request); if
  unsure, leave them off and ask on the confirmation screen (step 3).
- **Features (blank only)** → module names the request names (lower case, `limits.moduleNameMax`
  characters, at most `limits.maxModules`, not in `reservedModuleNames`); none otherwise.
- **Theme** → the family of `themes.families` whose `suits` fits the game the user describes; none
  (the template default) when nothing fits or `themes.families` is empty. Pass `primary` / `accent`
  only when the user names colours (`#RRGGBB`).
- **Company name → never passed**: the generator takes the package's second segment, capitalized
  (`com.example.skyhopper` → `Example`). It becomes the C# namespace `<Company>.<Project>`; show it.
- **IDs → never asked**: the test IDs / placeholders stay (`idGroups`: AdMob, RevenueCat, game
  services); the generator reports each as a warning.
- **Min SDK / iOS → `defaults.minSdk` / `defaults.iosVersion`**, within `limits` (`minSdkMin`–
  `minSdkMax`, `iosVersionMin`–`iosVersionMax`).
- **Template → the pinned `template`** of `game_describe`. Never pass `templateRef` unless the user
  asks for a specific tag.

## 2. Ask ONLY these four — ONE at a time, in order
Ask one question → wait → validate (below) → ask the next. **Don't batch. Ask nothing beyond these
four.** Skip any the user already gave in their request.

1. **Project Name** — letters or digits, starting with a letter, no spaces, up to `limits.nameMax`
   (e.g. `SkyHopper`). Becomes the folder, the C# namespace and the APK name; not one of
   `reservedNames`.
2. **App Name** — the title on the home screen (e.g. `Sky Hopper`), up to `limits.appNameMax`.
   Offer the project name split into words as the default.
3. **Package Name** — offer the saved `packagePrefix` and the project name in lower case
   ("I'll build it as `com.example.<projectname>`"), or let them type the full package. Lower case,
   at least 3 segments, up to `limits.packageNameMax`, no keyword segment, not under
   `reservedPackagePrefix`. Its second segment becomes the company name.
4. **Output directory** — the parent folder: default `{outputDir}`; the project is created at
   `<outputDir>/<projectName>`. Show the resolved absolute path (expand `~`: `game_generate` needs
   an absolute `outputDir`). `<outputDir>/<projectName>` must not exist or must be empty.

### Validate each answer immediately
Apply the `game_describe` rules. If invalid, re-ask that same field with the reason; don't advance
until valid (cap ~2 re-asks). `game_generate`'s error is the final authority.

## 3. Confirm with an anatomy preview
Show a one-screen summary and a project tree, for example:

```
SkyHopper/                          ← /abs/output/SkyHopper
├── Assets/
│   ├── Editor/Build/BuildScript.cs   Example.SkyHopper.Editor.Build (batch builds)
│   ├── Scenes/                       Boot scene first
│   └── …                             showcase: the sample games; blank: Sample + your modules
├── Packages/  ProjectSettings/       Unity <unityVersion>
├── .cmpose/generation.json           the generation record
└── README.md                         signing, IDs, release checklist
```

Then the values: project, app name, package, company (namespace `<Company>.<Project>`), path,
**template (showcase/blank), render (2d/3d), flags and modules (blank), theme — from the request,
changeable here**, Min SDK, iOS, the Unity version (`unityVersion`) and the template (`repo@ref`).
Ask **one** yes/no ("Generate? — or tell me what to change").

## 4. Generate
Call `game_generate` with `projectName`, `appName`, `packageName`, `outputDir` (absolute),
`templateType`, `render`, `minSdk`, `iosVersion`, and for blank `flags` / `features`, plus `theme`
when one was picked. Never `ids`, `companyName` or `templateRef` (unless asked).
- success → `structuredContent.projectDir` is the project; show each `warnings` entry **verbatim**;
  continue.
- error result → its text is the reason:

| error text | action |
|---|---|
| `projectName …` / `appName …` / `packageName …` / `companyName … is derived from packageName's second segment …` | re-ask that field (the package for `companyName`) with the message, retry once |
| `features entry "…" …` / `features allows at most …` | drop or rename that module (say so), retry once |
| `outputDir must be an absolute path …` | expand `~` / resolve the path, retry once |
| `… already exists and is not empty` / `… is a file` | ask for another output directory or project name, retry once |
| `Could not download the template …` (the first run downloads it) | ask the user to check the connection, retry once |
| anything else (`Generation failed: …`) | show it and stop |

Generation is local: there is no rate limit; never loop on the same error.

## 5. Setup
`scripts/setup.sh <projectDir>` → `git init` + initial commit (`OK: git`); a project that is already
a repository is left as is. The template ships the Unity `.gitignore`.

## 6. Verify + open Unity (capability-aware, background)
Run `scripts/doctor.sh "<unityVersion>"` once →
`{"node20","git","unity","androidModule","iosModule","xcode","iosSimSdk","pod"}`.
- `doctor.unity` null → the editor of that version is not installed: say so in one line (install
  Unity `<unityVersion>` in Unity Hub with the Android and iOS Build Support modules, or set
  `UNITY_EDITOR`), skip the builds and the opening.
- **A batch build cannot run while the editor has the project open** (the project lock), so the
  order is: builds first, then open. If the user wants the project open right away, skip the builds
  and say so ("the builds are skipped because Unity has the project open").
- Otherwise run **in the background, one after the other** (Unity cannot build one project twice at
  the same time), as a single background command:
  - if `defaults.autoBuildAndroid` **and** `doctor.androidModule`: `scripts/build-android.sh
    <projectDir>` → `OK: APK <path> (<size>)` (about 8–10 min on the first import);
  - then, if `defaults.autoBuildIos` **and** `doctor.iosModule`, `doctor.xcode` and
    `doctor.iosSimSdk`: `scripts/build-ios.sh <projectDir>` → `OK: iOS simulator build`.
  Tell the user they run and continue with step 7; report each line as it arrives.
- When the builds are done (or skipped), if `defaults.openUnity` and `doctor.unity` is not null:
  `open -a "<editor dir>/Unity.app" --args -projectPath "<projectDir>"` (`<editor dir>` is
  `doctor.unity` without `/Unity.app/Contents/MacOS/Unity`).
- A missing capability → say so in one line and skip (no Android module / iOS module: add it in
  Unity Hub; no full Xcode or no simulator SDK: install it; no `pod` with a Podfile: install
  CocoaPods). Never fail the whole flow; a `SKIP:` line is not an error.
- A `FAIL:` from a build on a freshly generated project is a **generator/template defect**, not the
  user's code: show the lines and say so; do not patch the project. An environment error in those
  lines (a download, a licence, a lock file, the time limit) is not a defect: show it and say what
  to fix. The logs are in `<projectDir>/Builds/logs/`.
- The game is not launched on an emulator or a simulator.

## 7. Report + remember
Summarize:
- the absolute project path, the template (`repo@ref`), the template type, render, theme and, for
  blank, the flags and modules;
- the warnings verbatim, and: **the project keeps the test IDs (AdMob test ads, the RevenueCat Test
  Store key, placeholder leaderboard IDs); enter your real IDs before release** (`README.md` of the
  project: signing, IDs, release checklist);
- how to open and run it: Unity Hub → Add → the project folder, editor `<unityVersion>` (Android
  and iOS Build Support); press Play in the Boot scene, or build with File > Build Profiles;
- the build results as they arrive.
Offer to persist any changed preferences (`packagePrefix`, `outputDir`, `render`, `minSdk`,
`iosVersion`, `openUnity`, `autoBuildAndroid`, `autoBuildIos`) back to `defaults.json`.

## Notes
- The first generation downloads the pinned template into `~/.cache/cmpose`
  (`CMPOSE_CACHE_DIR` overrides it); later runs are offline.
- A generated project is only as correct as the pinned template of the installed `@cmpose/mcp`; to
  get a newer template, install a newer MCP version.
- The builds stop after `UNITY_BUILD_TIMEOUT` seconds per step (default 1800).
- The install command above must stay identical to `cmp-new-project`'s (`scripts/check-skills.sh`
  checks it).
