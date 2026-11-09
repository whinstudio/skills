# game-brief

> A one-page brief for a Unity 6 mobile game, and a read-only scope check against it.

Before code, one file: `design/brief.md`, short enough to read on one screen. It holds the pitch,
core loop, player goal and fail state, an MVP of at most seven items, what is out of scope, the build
order (riskiest first), three pillars and an anti-pillar, art direction, a reference game, and the
mobile fields: orientation, one-handed, session length, revenue model and stores.

## Requirements

- [Claude Code](https://code.claude.com)
- `git`, for the scope check

## Install

```bash
# from the repo root
ln -s "$PWD/game-brief" ~/.claude/skills/game-brief   # recommended
# or: cp -R game-brief ~/.claude/skills/
```

## Usage

```text
/game-brief brief a one-finger escape game
/game-brief scope-check
"what should we prepare before coding a tap-to-dodge game?"
"does adding a shop still fit the brief?"
```

The skill asks only what it cannot infer, in one message, and marks its own guesses in the file.

## Scope check

Compares `git log`, TODO comments and project files with the brief's MVP and out-of-scope lists, and
counts items added and removed. Net change of 10% or less is `PASS`, up to 25% `CONCERNS`, above
that `FAIL`. Without a brief the result is `NOT ASSESSED`. It writes no file.

## Output

- `design/brief.md`. The `**Orientation:**` line is read by [`game-smoke`](../game-smoke).

## License

Adapted and shortened for Unity 6 mobile from Claude Code Game Studios (MIT). See
[LICENSE-UPSTREAM.md](./LICENSE-UPSTREAM.md).
