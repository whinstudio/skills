# game-release

> Check whether a Unity 6 mobile game generated from the cmpose template is ready for Google Play
> and the App Store, and write a short post-mortem after launch.

The skill checks this template's real files with exact commands: the Android bundle built with
`-cmposeAab`, signing with `keystore.properties`, version numbers, IL2CPP ARM64, leftover test ad
and purchase ids, `PrivacyInfo.xcprivacy`, store images, size, and whether the newest `game-smoke`
report is current and passing. Things only the owner can do (store consoles, a real device, legal
text) are listed and stay `NOT ASSESSED` until you confirm them.

Verdict, first match: `NOT READY`, `NOT ASSESSED`, `READY`.

## Requirements

- [Claude Code](https://code.claude.com)
- A Unity 6 project from the cmpose template, closed in the Unity editor, with Unity Hub or
  `UNITY_EDITOR` set
- A current [`game-smoke`](../game-smoke) report in `qa/`

## Install

```bash
# from the repo root
ln -s "$PWD/game-release" ~/.claude/skills/game-release   # recommended
# or: cp -R game-release ~/.claude/skills/
```

## Usage

```text
/game-release
"is the game ready for the stores?"
"write a post-mortem for the game"
```

If `app-store-rejection-checker` or `play-store-rejection-checker` is installed, the skill tells you
to run it as the last step. Neither is required.

## Output

- `qa/release-<date>.md`: one row per check, the owner rows, the verdict
- `design/post-mortem.md`: goal vs result, what went well, what went badly, three lessons

The skill changes nothing else in the project, except `Builds/` and `Library/` when it builds the bundle.

## License

Adapted and shortened for Unity 6 mobile from Claude Code Game Studios (MIT). See
[LICENSE-UPSTREAM.md](./LICENSE-UPSTREAM.md).
