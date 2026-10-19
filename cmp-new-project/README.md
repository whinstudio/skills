# cmp-new-project

> Generate a Compose Multiplatform (Kotlin Multiplatform) project from the terminal
> with the cmpose generator, running on your machine as the cmpose MCP server.

When invoked, the skill asks **only four things** (one at a time), uses smart
defaults for the rest, then generates the project locally, sets up the project,
opens the IDE, and verifies the Android/iOS builds.

## Requirements

- [Claude Code](https://code.claude.com)
- The cmpose MCP server, added once (Node.js 20+ and git):

      claude mcp add cmpose -- npx -y @cmpose/mcp@0.5.3

  then restart Claude Code. Without it the skill stops and prints this command.
- Internet access once, for the first generation (it downloads the pinned template)
- Optional, for the local build/run verification:
  - **JDK 21** (the template uses AGP 9) — Android build
  - **Android SDK** — Android build
  - **macOS + Xcode** — iOS simulator run
- `npm` — only to (re)generate the contract with `sync-contract.sh`

The skill **degrades gracefully**: missing tools are skipped and reported, never fatal.

## Install

```bash
# from the repo root
ln -s "$PWD/cmp-new-project" ~/.claude/skills/cmp-new-project   # recommended
# or: cp -R cmp-new-project ~/.claude/skills/
```

Start a new Claude Code session and run `/cmp-new-project`.

## Usage

Invoke the skill and answer four prompts (asked one at a time):

1. **Project name** — letters only → `rootProject.name`
2. **App name** — the user-visible name
3. **Package name** — offered as `com.example.<segment>` (Android `applicationId` + iOS bundle id)
4. **Output directory** — default `~/StudioProjects` (the project goes to `~/StudioProjects/<project>`)

Everything else uses smart defaults (shown on the confirmation screen, changeable
there or in your request):

- **Template** → `showcase` (full example app: home + onboarding + monetization + all modules)
- **Min SDK** → `24`   ·   **iOS** → `15.0`
- **Features / custom modules** → applied **only** if you mention them in your request

Examples:

```text
/cmp-new-project
"yeni bir compose multiplatform projesi oluştur"
"network ve theming'li blank bir proje, profile ve cart modülleriyle"
```

The last one switches to a **blank** project with networking + theming + two custom
modules — taken from the request, so no extra questions are asked.

### Backend (`backend`)

Ask for it explicitly — a server, sign-in or sharing data between users (e.g. "blank
proje, sunucu ve girişle", "a blank app with a backend and sharing"). It is blank-only and
turns on `multiLang` and `network`. The project then has a Ktor server in `server/`,
`core/api`, `core/auth` (Firebase sign-in: email, Google, Apple), `feature/account` and
`feature/sharing` (spaces, members, invites as `<scheme>://invite/<token>`); `account` and
`sharing` become reserved module names.

After generation:

1. Add your own Firebase config files (`androidApp/google-services.json`,
   `iosApp/iosApp/GoogleService-Info.plist`). Never commit them.
2. Start the local server: `./gradlew :server:runLocal` (embedded PostgreSQL kept in
   `.local-server/`; `./gradlew :server:resetLocal` wipes it).
3. Add the app's own data with the [`cmp-backend`](../cmp-backend) skill.

## Configuration — `defaults.json`

| key | default | meaning |
|---|---|---|
| `packagePrefix` | `com.example` | package prefix offered for the package question |
| `outputDir` | `~/StudioProjects` | where projects are created |
| `minSdk` / `iosVersion` | `24` / `15.0` | default SDK / iOS target |
| `ide` / `openIde` | `Android Studio` / `true` | IDE opened after generation |
| `autoBuildAndroid` / `autoRunIos` | `true` / `true` | post-generation verification |

**Model / effort:** the skill runs on **Sonnet (medium effort)** via `SKILL.md`
frontmatter — the reliability/cost sweet spot for this mostly mechanical flow — and
your session model resumes afterward.

## How it works

1. Checks that the cmpose MCP tools (`cmp_describe`, `cmp_generate`) are connected; stops with the install command otherwise.
2. `cmp_describe` → the generator's limits, defaults and pinned template.
3. Collect the four fields; validate each against `reference/contract.json`.
4. Confirm with a project **"anatomy"** preview (the module tree).
5. `cmp_generate` → the project is written to `<outputDir>/<projectName>`.
6. `scripts/setup.sh` → write `local.properties` (`sdk.dir`) + `git init` + initial commit.
7. `scripts/doctor.sh` → capabilities → `build-android.sh` / `run-ios.sh` (background, optional).

## Contract stays in sync with the generator

`reference/contract.json` and `reference/payload.md` are **generated** from `@cmpose/core` (the
library the cmpose MCP runs) by `scripts/sync-contract.sh`. A skill clone that lags behind is
reported at runtime (its `contractVersion` differs from `cmp_describe`'s), and the MCP's limits are
used:

```bash
CMP_CORE_VERSION=0.3.0 bash scripts/sync-contract.sh     # regenerate from that npm version
bash scripts/sync-contract.sh --check                    # drift gate (the pinned version)
# exit codes: 0 = in sync, 1 = drift, 2 = configuration error (node / npm / core version)
```

## Files

```
cmp-new-project/
├── SKILL.md            # the flow Claude follows
├── defaults.json       # your preferences
├── reference/
│   ├── contract.json   # generated, machine-readable contract
│   └── payload.md      # generated, human-readable contract
└── scripts/
    ├── sync-contract.sh# (re)generate the contract from @cmpose/core (+ --check)
    ├── doctor.sh       # environment capability probe
    ├── setup.sh        # local.properties + git
    ├── build-android.sh# assembleDebug (config cache on) + APK check + unit tests + detekt if enabled (JDK 21)
    └── run-ios.sh      # build + install + launch on a simulator
```

## Notes

- Generation is local: no account, no API key, no upload, no rate limit.
- A generated project is only as correct as the pinned template of the installed `@cmpose/mcp`.
