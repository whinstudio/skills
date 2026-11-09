# game-look

> One reference image, one page of rules, assets made from both, checked on a device screenshot.

Keeps the art of a Unity 6 mobile game looking like one game. The skill fixes a single reference
image, writes `design/look.md` (palette, shape language, line, light, perspective, detail level,
what must never appear), makes every new asset from that image and page, compares it side by side
in a contact image, and play-tests it on a device with `game-smoke`: one change per round, at most
three rounds, then a report of what is left.

A visual task is not done without a screenshot. If `game-smoke` returns `Visual: NOT DONE`, so is
this.

## Requirements

- [Claude Code](https://code.claude.com)
- The [`game-smoke`](../game-smoke) skill and what it needs (Unity, Android SDK or Xcode)
- An image tool in the session, or images you supply
- `ffmpeg` for the contact image (`sips` or ImageMagick work too)

## Install

```bash
# from the repo root
ln -s "$PWD/game-look" ~/.claude/skills/game-look   # recommended
# or: cp -R game-look ~/.claude/skills/
```

## Usage

```text
/game-look
"make the character and backgrounds look like one game"
"match everything to art/ref.png"
```

## Output

- `design/look.md`
- `qa/look/` contact images, `qa/evidence/` screenshots from `game-smoke`
- a report: reference, rounds, before and after screenshots, what is left

Out of scope: 3D worlds and model pipelines. Only you can judge how the game feels.

## License

The screenshot rule is adapted from Claude Code Game Studios (MIT); the loop is original. See
[LICENSE-UPSTREAM.md](./LICENSE-UPSTREAM.md).
