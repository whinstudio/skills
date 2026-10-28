# skills

AI-optimized, modular **agent skills** for [Claude Code](https://code.claude.com),
following the open Agent Skills format — each skill is a folder with a `SKILL.md`
that the agent loads on demand.

Inspired by the structure of [`android/skills`](https://github.com/android/skills).

## What's a skill?

A skill is a directory containing a `SKILL.md` (instructions + YAML frontmatter)
plus any supporting `scripts/` and `reference/` files. Claude Code auto-loads a
skill when your request matches its `description`, or you can invoke it explicitly
with `/<skill-name>`.

## Available skills

| Skill | What it does |
|---|---|
| [`cmp-new-project`](./cmp-new-project) | Generate a Compose Multiplatform (Kotlin Multiplatform) project from the terminal through the local cmpose MCP server (`@cmpose/mcp`), asking only four questions. |
| [`backend-new-project`](./backend-new-project) | Generate a standalone Kotlin/Ktor backend (PostgreSQL, Docker-ready) through the same cmpose MCP server, asking only four questions, then verify the Gradle build and the Docker image. |
| [`game-new-project`](./game-new-project) | Generate a Unity 6 mobile game (Android + iOS, 2D or 3D) through the same cmpose MCP server, asking only four questions, then build Android and the iOS simulator in the background. |
| [`cmp-feature`](./cmp-feature) | Add a screen, feature module or data source to a generated app — the contract, domain, data and presentation layers, ViewModel, navigation destination and Koin wiring. |
| [`cmp-design-to-code`](./cmp-design-to-code) | Build or adjust UI from a provided design (exported boards, mockup or screenshot) by measuring it, mapping every value to a theme token and checking the result against the design. |
| [`cmp-code-rules`](./cmp-code-rules) | Rules for every Kotlin change in a generated project — layering, visibility, Multiplatform limits, Compose state, Koin annotations, resources, accessibility — plus a self-review checklist. |
| [`cmp-testing`](./cmp-testing) | Add or fix unit tests for ViewModels, use cases, repositories and mappers, and repair a test gate that is red, counts zero tests or hangs. |
| [`cmp-maestro`](./cmp-maestro) | Write or repair Maestro flows, including the walkthrough used to record the demo video on Android and iOS, and add the test tags they select by. |
| [`cmp-backend`](./cmp-backend) | Add the app's own data to the server (the cmpose backend template) in projects generated with backend — a new migration with `space_id`, a `feature/<name>` package with its table, repository, `/api/v1` routes behind `requireUser` and `requireRole` and its OpenAPI entries, the IDOR and validation tests, the `core/api` model checked by `ApiContractTest`, the client repository, ViewModel, screen and Maestro step. |
| [`cmp-detekt`](./cmp-detekt) | Run detekt in projects that have the detekt gate, auto-correct formatting first, then fix the remaining findings at their cause without suppressions, baselines or config changes. |
| [`cmp-verify`](./cmp-verify) | When to build, how to read gate output, and recipes for the common Kotlin Multiplatform, KSP, Koin and Compose resources failures. |
| [`cmp-gates`](./cmp-gates) | Run the finish gates in a separate Sonnet subagent and get a short pass/fail report; fixes only mechanical failures with a written recipe and reports the rest. |
| [`cmp-commit`](./cmp-commit) | On explicit request, split the work into atomic commits, run the finish gates and write Conventional Commits messages — committing only, never pushing unless asked. |
| [`cmp-matrix-test`](./cmp-matrix-test) | Run the cmpose generator's release matrix (every variant built and launched as a release build on an Android emulator and an iOS simulator) through the smoke gate of the private release-tools repo, and report with screenshots. Requires a checkout of that repo. |
| [`account-delegate`](./account-delegate) | Offer to hand a self-contained job to a second Claude Code account on the same machine (headless, live in a side cmux pane) and bring its report — or a worktree branch to merge — back to your main session. |

**Models.** Skills that write application code (`cmp-code-rules`, `cmp-feature`,
`cmp-design-to-code`, `cmp-backend`) run on your session model. Mechanical skills run in their own subagent on
Sonnet and return a short report (`cmp-gates`, `cmp-detekt`, `cmp-testing`, `cmp-maestro`);
`cmp-commit`, `cmp-new-project`, `backend-new-project`, `game-new-project` and `cmp-matrix-test` run on Sonnet. `scripts/check-skills.sh`
enforces these rules.

**cmpose MCP.** The three `*-new-project` skills need the cmpose MCP server. If it is not
connected, the skill asks nothing and prints the install command:
`claude mcp add cmpose -- npx -y @cmpose/mcp@0.8.9`. All three show the same
pinned command (from `cmp-new-project/reference/contract.json`); `scripts/check-skills.sh` keeps
them in step.

[`compass-kit`](./compass-kit) is not a skill but a kit that Compass installs into every project
it generates. Its `kit.json` lists the skills it ships — `cmp-code-rules`, `cmp-feature`,
`cmp-design-to-code`, `cmp-maestro`, `cmp-testing`, `cmp-verify`, `cmp-gates`, `cmp-commit`, for
projects with detekt `cmp-detekt` and, for projects with a backend (`server/`, generated from the cmpose backend template), `cmp-backend` — together with the finish gates those skills run.
`cmp-matrix-test` also runs detekt with the kit's `detekt.yml`. See [compass-kit](#compass-kit) below for its contents.

## Install

Skills live in `~/.claude/skills/` (personal) or `<project>/.claude/skills/`
(project-scoped). Clone this repo, then install a skill by **symlink** (recommended —
you keep getting updates with `git pull`) or by **copy**:

```bash
git clone https://github.com/whinstudio/skills.git
cd skills

# symlink (recommended)
ln -s "$PWD/cmp-new-project" ~/.claude/skills/cmp-new-project

# …or copy
cp -R cmp-new-project ~/.claude/skills/
```

Start a new Claude Code session and run `/cmp-new-project`. Each skill's own
`README.md` lists its requirements and usage.

## Repository layout & conventions

- **One directory per skill** at the repo root, named in `kebab-case` matching the
  skill's `name:` field.
- Each skill dir contains `SKILL.md` (required), an optional `README.md`, and any
  `scripts/` / `reference/` it needs.
- As the collection grows, skills may be grouped into domain folders
  (e.g. `compose/`, `android/`), following the `android/skills` convention.

```
skills/
├── README.md
├── LICENSE
└── cmp-new-project/
    ├── SKILL.md
    ├── README.md
    ├── defaults.json
    ├── reference/
    └── scripts/
```

## Contributing

1. Create `<skill-name>/SKILL.md` with at least `name` and `description` frontmatter.
2. Add a `README.md` documenting the skill's requirements and usage.
3. Keep heavy / deterministic work in `scripts/`; keep `SKILL.md` focused on
   orchestration so it stays small and cheap to run.

## Disclaimer

These skills are AI-optimized instructions. Review what a skill does before running
it — some execute shell commands and call external APIs.

## License

[MIT](./LICENSE) © 2026 Kerem Turker

## compass-kit

`compass-kit/` is what Compass installs into every project it generates: the skills listed in
`kit.json`, `CLAUDE.md` (Compass fills in the `<!-- compass:gates -->` line), a project
`settings.json` that registers `hooks/secrets-guard.py` (blocks secrets) and
`hooks/walkthrough-guard.py` (a saved Maestro flow must close the keyboard after typing) and turns
commit/PR attribution off, and
the detekt configuration.
The gates in `kit.json` are both what the coding agent is told to run and what Compass runs
itself before it calls the app ready.

Hook tests: `sh compass-kit/hooks/test_secrets_guard.sh`, `sh compass-kit/hooks/test_walkthrough_guard.sh`
