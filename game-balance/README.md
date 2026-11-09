# game-balance

> Economy and difficulty templates for a Unity 6 mobile game, and a check that compares the real data with your stated targets.

`economy` writes `design/economy.md`, `difficulty` writes `design/difficulty.md`. `check` reads
`Assets/_Project/Compass/Resources/GameEconomy.json` (when the game has one) and the tuning assets, compares each
value with a target you stated, and ends with one verdict: `BALANCED`, `CONCERNS`, `UNBALANCED` or
`NOT ASSESSED — NO DATA`. It never makes up a target. Values without one are listed as not judged. It also checks
fairness rules (no pay-to-win, wheel odds visible, no timer pressure on essentials) where the data shows them.

It changes no game file. It writes only the two design files and, when asked, `qa/balance-<date>.md`.

## Requirements

- [Claude Code](https://code.claude.com)
- A `design/brief.md` from `game-brief` helps (session length, revenue) but is not required

## Install

```bash
# from the repo root
ln -s "$PWD/game-balance" ~/.claude/skills/game-balance   # recommended
# or: cp -R game-balance ~/.claude/skills/
```

## Use

```
/game-balance economy
/game-balance difficulty
/game-balance check save
```

## License

Adapted and shortened from Claude Code Game Studios (MIT). See `LICENSE-UPSTREAM.md`.
