# backend-new-project

> Generate a standalone Kotlin/Ktor backend from the terminal with the cmpose
> generator, running on your machine as the cmpose MCP server.

When invoked, the skill asks **only four things** (one at a time), takes the rest
from your request, then generates the project locally, sets up git, opens the IDE,
and verifies the Gradle build and the Docker image.

The generated backend: Kotlin on JVM 21, Ktor, Exposed, Flyway, PostgreSQL,
Firebase ID tokens verified on the server, a sample feature to copy, an OpenAPI
description, a local runner with an embedded PostgreSQL and a `deploy/` folder
(Dockerfile, compose fragment, nginx location, database script).

## Requirements

- [Claude Code](https://code.claude.com)
- The cmpose MCP server, added once (Node.js 20+ and git):

      claude mcp add cmpose -- npx --prefer-offline -y @cmpose/mcp@0.5.0

  then restart Claude Code. Without it the skill stops and prints this command.
- Internet access once, for the first generation (it downloads the pinned template)
- Optional, for the verification:
  - **JDK 21** — `./gradlew build` (compile, tests, detekt)
  - **Docker** (a running daemon) — the image build

The skill **degrades gracefully**: missing tools are skipped and reported, never fatal.

## Install

```bash
# from the repo root
ln -s "$PWD/backend-new-project" ~/.claude/skills/backend-new-project   # recommended
# or: cp -R backend-new-project ~/.claude/skills/
```

Start a new Claude Code session and run `/backend-new-project`.

## Usage

Invoke the skill and answer four prompts (asked one at a time):

1. **Project name** — letters only (e.g. `NotesBackend`) → the folder and Gradle project
2. **App name** — the service name (e.g. `notes-backend`); also the URL path, the Docker
   image and the database name. Checked against the generator's reserved names.
3. **Package name** — offered as `com.example.<projectname>`
4. **Output directory** — default `~/StudioProjects` (the project goes to `~/StudioProjects/<project>`)

**Sharing** is never asked: it is on when your request mentions sharing between users
(sharing, invite, family, team, members, roles / paylaşım, davet, aile, ekip, üyeler,
roller), off otherwise. It is shown on the confirmation screen, where you can change it.
Sharing adds spaces, roles (viewer, editor, owner) and invitation links.

Examples:

```text
/backend-new-project
"bana bir backend hazırla"
"create a Kotlin backend with sharing"
```

After generation:

1. Create `.local-server/config.properties` with `firebaseProjectId=<your Firebase project id>`.
2. `./gradlew runLocal` → `http://localhost:18001/health` (`./gradlew resetLocal` wipes the local database).
3. Add features under `feature/<name>/` by copying `feature/sample`; go through `SECURITY-CHECKLIST.md`.
4. Deployment: `deploy/README.md`.

## Configuration — `defaults.json`

| key | default | meaning |
|---|---|---|
| `packagePrefix` | `com.example` | package prefix offered for the package question |
| `outputDir` | `~/StudioProjects` | where projects are created |
| `ide` / `openIde` | `IntelliJ IDEA` / `true` | IDE opened after generation (falls back to Android Studio) |
| `autoBuild` | `true` | run `./gradlew build` after generation (JDK 21) |
| `autoDockerBuild` | `true` | build the Docker image after generation (Docker daemon) |

**Model / effort:** the skill runs on **Sonnet (medium effort)** via `SKILL.md`
frontmatter, and your session model resumes afterward.

## How it works

1. Checks that the cmpose MCP tools (`backend_describe`, `backend_generate`) are connected; stops with the install command otherwise.
2. `backend_describe` → the app name rules, the project anatomy, the conventions and the pinned template (no static contract copy).
3. Collect the four fields; validate each against those rules.
4. Confirm with a project tree preview.
5. `backend_generate` → the project is written to `<outputDir>/<projectName>`.
6. `scripts/setup.sh` → `git init` + initial commit.
7. `scripts/doctor.sh` → capabilities → `build.sh` / `docker-build.sh` (background, optional).

## Scripts

Every script prints `OK: …`, `SKIP: …` (a missing tool, exit 0) or `FAIL: …` (exit 1).

```
backend-new-project/
├── SKILL.md            # the flow Claude follows
├── defaults.json       # your preferences
└── scripts/
    ├── doctor.sh       # capabilities JSON: node20, git, jdk21, docker, ide
    ├── setup.sh        # git init + initial commit → OK: git
    ├── build.sh        # ./gradlew build → OK: BUILD SUCCESSFUL, OK: tests <n>, OK: DETEKT CLEAN
    └── docker-build.sh # docker build -t <appName>:local + non-root user check
```

## Notes

- Generation is local: no account, no API key, no upload, no rate limit.
- A generated project is only as correct as the pinned template of the installed `@cmpose/mcp`.
