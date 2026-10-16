---
name: cmp-new-project
model: sonnet
effort: medium
description: >-
  Scaffold a new Compose Multiplatform (Kotlin Multiplatform) project with the
  cmpose generator, which runs on this machine as the cmpose MCP server
  (cmp_describe, cmp_generate). Use whenever the user wants to create / generate /
  scaffold / bootstrap a new CMP or KMP project — e.g. "bana network ve theming'li
  bir proje hazırla", "yeni bir compose multiplatform projesi oluştur", "create a CMP
  project with networking and a profile module", "örnek uygulama oluştur". When
  invoked the skill asks ONLY four fields — project name, app name, package, output
  directory — one at a time; everything else uses smart defaults or the request
  (template = showcase, Min SDK, iOS, and any features/modules) and is NEVER asked.
  Then it generates the project locally, sets up local.properties + git, opens the
  IDE, and verifies Android + iOS builds.
---

# cmp-new-project

Generate a Compose Multiplatform project with the cmpose generator. It runs on this machine as
the cmpose MCP server (`@cmpose/mcp`, tools `cmp_describe` and `cmp_generate`): no account, no API
key, no upload. **Kept short**: ONLY four fields are asked one at a time (project name, app name,
package, output dir); everything else uses smart defaults / the request and is shown (changeable)
at the confirmation step. Skill directory: `~/.claude/skills/cmp-new-project/`.

Run scripts with `bash ~/.claude/skills/cmp-new-project/scripts/<name>.sh`.
The contract is generated from `@cmpose/core`; at runtime it is compared with `cmp_describe`, so a
stale skill is visible — see *Maintenance*.

## 0. MCP check + contract + preferences (silent)
1. **The cmpose MCP server must be connected.** Its tools are `cmp_describe` and `cmp_generate`
   (usually listed as `mcp__cmpose__cmp_describe` / `mcp__cmpose__cmp_generate`). If they are not
   available in this session, **stop before asking anything** and tell the user, in their language:
   - the generator runs locally as an MCP server; add it once with this command (the same as
     `reference/contract.json` → `mcp.install`), then restart Claude Code (`/exit`, then `claude`)
     and ask again:

         claude mcp add cmpose -- npx --prefer-offline -y @cmpose/mcp@0.2.8

   - it needs Node.js 20+ and git: run `scripts/doctor.sh` and report `node20` and `git` (if it
     cannot run, just say so).
   Never generate any other way (no web API, no copying a template by hand).
2. Read `reference/contract.json` (regexes, max lengths, generator messages, dependency rules,
   `anatomy`, TR+EN `keywordMap`) and `defaults.json` (prefs).
3. Call `cmp_describe` once.
   - Its `contract.limits` OVERRIDE contract.json's numeric ranges + `maxModules`; `template` is the
     pinned template (`repo`, `ref`) shown in the confirmation.
   - If its `contractVersion` differs from contract.json's `contractVersion`, tell the user one line:
     "Note: this skill's contract differs from the installed cmpose MCP (update your skills clone, or
     install the MCP version in `reference/contract.json` → `mcp.install`); the MCP's limits are used."
     and carry on.
4. **Pre-fill from the request:** if the user already named a field (project name, features,
   modules, "blank", a specific SDK/iOS, etc.), use it — via `keywordMap` / `templateKeywords` — as
   that field's value. This can both set the defaults in step 1 and skip an asked field in step 2.

## 1. Auto-defaults — DO NOT ASK these (keep the form short)
Use these silently. They appear in the confirmation (step 3); the user changes any there if
needed, or overrides them up front in their request.
- **Template type → `showcase`** by default. Use `blank` ONLY if the request clearly indicates it
  ("blank", "boş proje", "no example screens", or it names specific `featuresConfig` toggles / a
  custom set of features). Showcase ⇒ `home` + `onboarding` + all sample core modules;
  `featuresConfig` is ignored. Custom modules are still added next to `home` and `onboarding`, fully
  wired (their screens are registered; the showcase still opens on onboarding).
- **Min SDK → `defaults.minSdk`** (validate against `cmp_describe` `contract.limits.minSdkMin/Max`).
- **iOS Deployment Target → `defaults.iosVersion`** (validate `regex.iosVersionFormat`, within
  `contract.limits.iosVersionMin/Max`).
- **Features + custom modules → from the request ONLY, NEVER asked.** Parse via `keywordMap` /
  module names. For the default `showcase` the `featuresConfig` toggles are ignored by the
  generator, but named modules go in `features`. If the request says `blank` but names no features,
  use blank-minimal (all `featuresConfig` false, `features: []`). Apply dependency rules
  (`networkInspector ⇒ network`, `theming || multiLang ⇒ dataStore`).
  **Turn on `purchases` / `ads` only when the user explicitly asks for in-app purchases / a paywall
  (custom paywall on RevenueCat) or for ads (AdMob).** Never infer them from words like "premium",
  "subscription", "purchases" or "satın alma" alone (a "premium-feeling recipe app" or a
  "subscription tracker" is not a paywall request); if unsure, leave them off and ask on the
  confirmation screen (step 3). `purchases` (custom paywall (Compose, on `PurchasesManager`)) and
  `ads` (AdMob banner/interstitial/rewarded) are independent; with both on, premium hides the ads.
  Either one adds `feature/monetization`, so `monetization` is a reserved module name (see
  `reference/payload.md` → *Monetization*).
  **Turn on `room` only when the user asks for a local database or offline storage of structured
  data; DataStore (`dataStore`) is for preferences.** `room` implies nothing and adds `core/room`
  plus, in blank, a `feature/notes` demo (so `notes` is a reserved module name; see
  `reference/payload.md` → *Room*).
  **Turn on `backend` only when the user explicitly asks for a server / backend, sign-in (accounts)
  or sharing data between users** (`keywordMap.backend`); an app that only shows accounts or a share
  button for plain text does not need it; if unsure, leave it off and ask on the confirmation
  screen. `backend` is blank-only (it switches the template to blank) and implies `multiLang` +
  `network` (and so `dataStore`). It adds `server/` (Ktor), `core/api`, `core/auth`,
  `feature/account` and `feature/sharing`, so `account` and `sharing` are reserved module names (see
  `reference/payload.md` → *Backend*).
- **CI → `ci: false`** by default, for both templates. Set `ci: true` only when the request asks for
  CI / GitHub Actions (`projectOptionKeywords.ci`). It is a top-level field, not a `featuresConfig`
  flag, so it never switches the template to blank. Never asked.

## 2. Ask ONLY these four — ONE at a time, in order
Ask one question → wait → validate (below) → ask the next. **Don't batch. Ask nothing beyond these
four.** Skip any the user already gave in their request.

1. **Project Name** — free text. Letters only (`regex.projectName`), ≤ `maxLengths.projectName`.
   Becomes `rootProject.name`.
2. **App Name** — free text. User-visible name; spaces OK, ≤ `maxLengths.appName`.
3. **Package Name** — offer the saved `packagePrefix` (e.g. `com.example`) and ask for the last
   segment ("I'll build it as `com.example.<seg>`"), or let them type the full package. Validate
   `regex.packageName`, ≤ `maxLengths.packageName`. Suggest the user's own reverse domain for an app
   they will publish.
4. **Output directory** — the parent folder: default `{outputDir}`; the project is created at
   `<outputDir>/<projectName>`. Show the resolved absolute path (expand `~`: `cmp_generate` needs an
   absolute `outputDir`). `<outputDir>/<projectName>` must not exist or must be empty.

### Validate each answer immediately
Apply `contract.json.regex` + `maxLengths` + the `cmp_describe` ranges. If invalid, re-ask that
same field and quote the exact `contract.json.messages` string; don't advance until valid (cap ~2
re-asks). `cmp_generate`'s error is the final authority.

## 3. Confirm with an anatomy preview
Show a one-screen summary + a module tree from `contract.json.anatomy` and the chosen config.
**Surface the auto-defaulted Template / Min SDK / iOS and say they can be changed here.** Mark
forced/auto modules.

```
Project: Sepetim          Package: com.example.sepetim
App:     Sepetim          Template: showcase (default — change if you want)
Min SDK: 24 (default)   iOS: 15.0 (default)   Output: ~/StudioProjects/Sepetim
CI:      off (default; GitHub Actions on pull requests + manual runs)
Template: whinstudio/cmpose-template @ template-YYYY.MM.DD (pinned by the cmpose MCP)

Sepetim/                              (showcase: full example app)
├── androidApp/  iosApp/  shared/ (Koin + Navigation)   always
├── core/  (logging (always), review (always), network, database (DataStore), room, designsystem, multilang, purchases, ads, …)
├── feature/home/  feature/monetization/  feature/onboarding/  (blank + room: feature/notes/)
├── server/  core/api/  core/auth/  feature/account/  feature/sharing/   (blank + backend only)
└── build-logic/
```
Get a single yes/no before generating.

## 4. Generate
- Call `cmp_generate` with `projectName`, `appName`, `packageName`, `outputDir` (absolute, the
  parent folder), `templateType`, `features` (`[]` if none), `minSdk`, `iosVersion` and `ci`
  (`false` unless the request asked for CI). **blank** → also `featuresConfig` with the chosen flags
  (send `"backend": false` unless it was turned on). **showcase** → no `featuresConfig`.
- The result:
  - success → `structuredContent.projectDir` is the project; show each `warnings` entry verbatim;
    continue.
  - error result → its text is the reason:
    - one of `contract.json.messages` → map it to the field, re-ask, retry once;
    - `… already exists and is not empty` / `… is a file` → ask for another output directory or
      project name, retry once;
    - `Unknown featuresConfig key(s): …` → fix the key from `cmp_describe` and retry once;
    - a template download error (the first run downloads the pinned template into
      `~/.cache/cmpose`) → ask the user to check the connection, retry once;
    - anything else → show it and stop.
- Generation is local: there is no rate limit; never loop on the same error.

## 5. Setup
`scripts/setup.sh <projectDir>` → `local.properties` (`sdk.dir`) + `git init` + initial commit.
Reports cleanly and continues if the Android SDK is absent.

## 6. Open IDE + verify (capability-aware, background)
Run `scripts/doctor.sh` once → capabilities JSON.
- If `defaults.openIde` and an IDE is available: `open -a "{ide}" <projectDir>`.
- If `defaults.autoBuildAndroid` **and** `doctor.canBuildAndroid`: run
  `scripts/build-android.sh <projectDir>` **in the background**; report `BUILD SUCCESSFUL` + the APK
  path when done, the unit tests (Android host) when the project has any (`UNIT TESTS PASS`, or
  skipped for older templates), and the detekt result: `DETEKT CLEAN`, or skipped when the project
  was generated without detekt. A red detekt or a red unit test on a freshly generated project is a
  generator/template defect, not the user's code: show the `e:` / FAILED lines and say so; report
  it, do not patch the project.
- If `defaults.autoRunIos` **and** `doctor.canRunIos`: run `scripts/run-ios.sh <projectDir>` **in
  the background**; report when the app launches.
- If a capability is missing, say so briefly and skip — never fail the whole flow. The build needs
  JDK 21: if `doctor.jdk21` is false, tell the user to install JDK 21 (e.g. Temurin 21).
Builds are long → background them and report results as they finish; never block.

## 7. Report + remember
Summarize: the absolute project path, the modules included (the anatomy), how to run (Android
Studio Run / iOS `iosApp` scheme), and the guide `https://whinstudio.github.io/cmpose/guide.html`.
If the project has `core/purchases`, say it ships with a RevenueCat Test Store key that must be
replaced with the user's own platform keys before shipping (a release build that still has the
Test Store key keeps purchases disabled and the paywall shows a message); if it has `core/ads`, say
it uses Google's test ad unit IDs and asks for UMP/ATT consent on the first visit to the ads screen
(a real app should ask at launch; the EEA consent debug geography is debug-only). If it has
`feature/notes`, say Notes is a demo: replace it or remove it. If it has `server/` (backend on), say
what to do next: add the user's own Firebase config files (`androidApp/google-services.json`,
`iosApp/iosApp/GoogleService-Info.plist`; never commit them), then start the local server with
`./gradlew :server:runLocal` (an embedded PostgreSQL kept in `.local-server/`;
`./gradlew :server:resetLocal` wipes it). Invite links open as `<scheme>://invite/<token>`. The
app's own data is added with the `cmp-backend` skill.
Add one line for deep links: "deep link: `<scheme>://`" (scheme = project name in lower case;
showcase opens `<scheme>://user/{username}` and `<scheme>://settings`, blank opens `<scheme>://` and
`<scheme>://<module>` for each custom module).
Offer to persist any changed preferences (`packagePrefix`, `outputDir`, `minSdk`, `iosVersion`,
`ide`, `openIde`, `autoBuildAndroid`, `autoRunIos`) back to `defaults.json`.

## Maintenance — keeping the contract in sync
`reference/contract.json` and `reference/payload.md` are **generated** by
`scripts/sync-contract.sh` from `@cmpose/core`. Do not hand-edit them.
- At each cmpose release: `CMP_CORE_VERSION=<x.y.z> bash scripts/sync-contract.sh` (an unreleased
  core: `CMP_CORE_DIR=<packages/core checkout>`). The contract facts and `contractVersion` come from
  the core; `mcp.install` pins `@cmpose/mcp` of the same release.
- Drift gate: `scripts/sync-contract.sh --check` (core version: `mcp.version` of the committed
  contract) exits 0 (in sync), 1 (drift) or 2 (configuration error: node / npm / core version).
- At runtime `cmp_describe`'s limits override the static numbers; `contract.json` is the offline
  fallback and the source for the regexes / message strings.

## Notes
- The first generation downloads the pinned template into `~/.cache/cmpose`
  (`CMPOSE_CACHE_DIR` overrides it); later runs are offline.
- A generated project is only as correct as the pinned template of the installed `@cmpose/mcp`.
