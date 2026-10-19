# cmp-matrix-test

Claude Code skill that runs the cmpose generator's release matrix (`npm run smoke` in
the private cmpose release-tools repo) and reports the result with screenshots.

## Requirements

- A checkout of the cmpose release-tools repo (`CMP_BACKEND_DIR`, required, no default;
  set it e.g. in your shell profile) and a local CmpTemplate clone
  next to it (or `CMP_TEMPLATE_REPO`).
- JDK 21, Android SDK with an AVD (`CMP_SMOKE_AVD`, default `Medium_Phone_API_36`) and
  `~/.android/debug.keystore`, Xcode with an iPhone simulator runtime.
- `ffmpeg` for a full run (release screenshots are checked for a dark background).

## Usage

`/cmp-matrix-test` — or ask "matris testini koş", "run the generator matrix on develop",
"quick smoke". Direct: `bash scripts/run.sh [--ref <tag|branch> | --dir <path>] [--build-only]`.
