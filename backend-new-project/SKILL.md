---
name: backend-new-project
model: sonnet
effort: medium
description: >-
  Scaffold a new standalone Kotlin/Ktor backend (Docker-ready, PostgreSQL,
  Firebase sign-in) with the cmpose generator, which runs on this machine as the
  cmpose MCP server (backend_describe, backend_generate). Use whenever the user
  wants to create / generate / scaffold a new backend, server or API project —
  e.g. "bana bir backend hazırla", "Ktor sunucu projesi oluştur", "paylaşımlı bir
  API sunucusu kur", "create a Kotlin backend with sharing", "scaffold a Ktor
  server". When invoked the skill asks ONLY four fields — project name, app name,
  package, output directory — one at a time; everything else (sharing) comes from
  the request and is NEVER asked. Then it generates the project locally, sets up
  git, opens the IDE, and verifies the Gradle build and the Docker image.
---

# backend-new-project

Generate a standalone Kotlin/Ktor backend with the cmpose generator. It runs on this machine as the
cmpose MCP server (`@cmpose/mcp`, tools `backend_describe` and `backend_generate`): no account, no
API key, no upload. **Kept short**: ONLY four fields are asked one at a time (project name, app name,
package, output dir); `sharing` comes from the request and is shown (changeable) at the confirmation
step. Skill directory: `~/.claude/skills/backend-new-project/`.

Run scripts with `bash ~/.claude/skills/backend-new-project/scripts/<name>.sh`.
There is no static contract copy: the rules are read from `backend_describe` at run time.

## 0. MCP check + contract + preferences (silent)
1. **The cmpose MCP server must be connected.** Its tools are `backend_describe` and
   `backend_generate` (usually listed as `mcp__cmpose__backend_describe` /
   `mcp__cmpose__backend_generate`). If they are not available in this session, **stop before asking
   anything** and tell the user, in their language:
   - the generator runs locally as an MCP server; add it once with this command, then restart Claude
     Code (`/exit`, then `claude`) and ask again:

         claude mcp add cmpose -- npx -y @cmpose/mcp@0.8.5

   - it needs Node.js 20+ and git: run `scripts/doctor.sh` and report `node20` and `git` (if it
     cannot run, just say so).
   Never generate any other way (no web API, no copying the template by hand).
2. Read `defaults.json` (prefs).
3. Call `backend_describe` once. It is the contract: `appNameRules` (`pattern`, `reserved`,
   `infrastructure`, `postgresReserved`, `postgresPrefix`, `sqlKeywords`), `options.sharing`
   (default + description), `anatomy` (stack, paths, routes, ports), `conventions` and `template`
   (the pinned `repo` + `ref`, shown in the confirmation).
4. **Pre-fill from the request:** if the user already named a field (project name, service name,
   package, folder), use it as that field's value and skip that question in step 2.

## 1. Auto-defaults — DO NOT ASK these (keep the form short)
- **Sharing → from the request ONLY, NEVER asked.** Turn it on when the request mentions sharing
  records between users: e.g. paylaşım, paylaşmak, paylaşımlı, ortak, davet, aile, ekip, takım,
  ortak liste, üyeler, roller / sharing, share with, shared, invite, family, team, shared list,
  members, roles. Otherwise off (`options.sharing.default`). Show it in the confirmation with its
  meaning: "records can be shared with other users: spaces, members (viewer / editor / owner),
  invitation links".
- **Template → the pinned `template`** of `backend_describe`. Never pass `templateRef` unless the user
  asks for a specific tag.

## 2. Ask ONLY these four — ONE at a time, in order
Ask one question → wait → validate (below) → ask the next. **Don't batch. Ask nothing beyond these
four.** Skip any the user already gave in their request.

1. **Project Name** — letters only, no spaces (e.g. `NotesBackend`). Becomes the folder and the
   Gradle root project name.
2. **App Name** — the service name; it is also the URL path, the Docker image and (with `-` → `_`)
   the database and database user name. Offer the project name in lower case with dashes as the
   default (e.g. `NotesBackend` → `notes-backend`). Validate against `appNameRules`: `pattern`; not in
   `reserved`, `infrastructure`, `postgresReserved` or `sqlKeywords`; no `postgresPrefix` (`pg-`).
3. **Package Name** — offer the saved `packagePrefix` and the project name in lower case
   ("I'll build it as `com.example.<projectname>`"), or let them type the full package. Reverse
   domain, lower-case segments. Suggest the user's own reverse domain for a service they will run.
4. **Output directory** — the parent folder: default `{outputDir}`; the project is created at
   `<outputDir>/<projectName>`. Show the resolved absolute path (expand `~`: `backend_generate`
   needs an absolute `outputDir`). `<outputDir>/<projectName>` must not exist or must be empty.

### Validate each answer immediately
Apply the `backend_describe` rules. If invalid, re-ask that same field with the reason; don't advance
until valid (cap ~2 re-asks). `backend_generate`'s error is the final authority.

## 3. Confirm with an anatomy preview
Show a one-screen summary and a project tree built from `backend_describe` → `anatomy.paths`
(replace `<package>` with the package as a path), for example:

```
NotesBackend/                     ← /abs/output/NotesBackend
├── src/main/kotlin/com/example/notes/
│   ├── config/  plugins/  auth/  users/  files/  openapi/
│   ├── feature/sample/           the shape to copy for new features
│   └── sharing/                  (sharing only)
├── src/main/resources/db/migration/   Flyway V<n>__<name>.sql
├── src/local/kotlin/             local runner (embedded PostgreSQL)
├── deploy/                       Dockerfile, compose fragment, nginx, SQL, .env.example
└── SECURITY-CHECKLIST.md
```

Then the values: project, app name (URL `/<appName>`, image `<appName>`, database
`<appName with _>`), package, path, **sharing on/off (from the request — changeable here)**, stack
(`anatomy.stack`) and template (`repo@ref`). Ask **one** yes/no ("Generate? — or tell me what to
change").

## 4. Generate
Call `backend_generate` with `projectName`, `appName`, `packageName`, `outputDir` (absolute) and
`sharing`.
- success → `structuredContent.projectDir` is the project; show each `warnings` entry verbatim;
  continue.
- error result → its text is the reason:

| error text | action |
|---|---|
| `Invalid input:` + `- projectName: …` / `- appName: …` / `- packageName: …` | re-ask that field with the message, retry once |
| `- outputDir: outputDir must be an absolute path` | expand `~` / resolve the path, retry once |
| `… already exists and is not empty` / `… is a file` | ask for another output directory or project name, retry once |
| a template download error (the first run downloads the template) | ask the user to check the connection, retry once |
| `The backend template is not released yet …` | say the installed MCP pins an unreleased template; stop |
| anything else (`Generation failed: …`) | show it and stop |

Generation is local: there is no rate limit; never loop on the same error.

## 5. Setup
`scripts/setup.sh <projectDir>` → `git init` + initial commit (`OK: git`); a project that is already
a repository is left as is.

## 6. Open IDE + verify (capability-aware, background)
Run `scripts/doctor.sh "{ide}"` once → `{"node20","git","jdk21","docker","ide"}`.
- If `defaults.openIde` and `doctor.ide` is not null: `open -a "<doctor.ide>" "<projectDir>"`
  (`defaults.ide`, default IntelliJ IDEA, falls back to Android Studio).
- If `defaults.autoBuild` **and** `doctor.jdk21`: run `scripts/build.sh <projectDir>` **in the
  background** (compile + tests + detekt); report `OK: BUILD SUCCESSFUL`, `OK: tests <n>` and
  `OK: DETEKT CLEAN` when done.
- If `defaults.autoDockerBuild` **and** `doctor.docker`: run
  `scripts/docker-build.sh <projectDir> <appName>` **in the background** (after the build, not at the
  same time); report `OK: image <appName>:local (user <u>)`.
- A missing capability → say so in one line and skip (no JDK 21: install JDK 21, e.g. Temurin 21; no
  Docker: start Docker Desktop). Never fail the whole flow; a `SKIP:` line is not an error.
- A `FAIL:` from the build, the tests, detekt or the image on a freshly generated project is a
  **generator/template defect**, not the user's code: show the lines and say so; do not patch the
  project. An environment error in those lines (a download, a permission, a lock file) is not a
  defect: show it and say what to fix.
- The local server is NOT started automatically (it needs a Firebase project id).

## 7. Report + remember
Summarize:
- the absolute project path, the template (`repo@ref`) and sharing on/off;
- the rules for writing code in it, from `backend_describe` → `conventions` (short): every
  `/api/v1` route calls `call.requireUser()` (with sharing `call.requireRole(...)`); a row the caller
  may not see answers 404 like a missing row; a new feature goes under `feature/<name>/` copying
  `feature/sample`, with a new migration and tests; a list that can grow pages (`limit`, `cursor`) and a small list
  with a fixed upper bound may answer in one array (when the sample feature is present, its
  `GET /api/v1/items` and `GET /api/v1/items/recent` show both), never an unbounded list; go through `SECURITY-CHECKLIST.md` for every new
  route or table;
- running locally: create `.local-server/config.properties` with
  `firebaseProjectId=<Firebase console → Project settings → Project ID>`, then `./gradlew runLocal`
  → `http://localhost:18001/health` (port: `anatomy.localPort`); `./gradlew resetLocal` wipes the
  local database;
- deployment: `deploy/README.md` (secrets come only from the environment);
- the build / image results as they arrive.
Offer to persist any changed preferences (`packagePrefix`, `outputDir`, `ide`, `openIde`,
`autoBuild`, `autoDockerBuild`) back to `defaults.json`.

## Notes
- The first generation downloads the pinned template into `~/.cache/cmpose`
  (`CMPOSE_CACHE_DIR` overrides it); later runs are offline.
- A generated project is only as correct as the pinned template of the installed `@cmpose/mcp`; to
  get a newer template, install a newer MCP version.
- The install command above must stay identical to `cmp-new-project`'s (`scripts/check-skills.sh`
  checks it).
