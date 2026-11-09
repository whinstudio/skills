---
name: game-balance
description: Use when a Unity 6 mobile game needs its economy or difficulty written down, or someone asks whether the economy or difficulty is balanced, whether prices, rewards, wheel odds or ad limits are fair, or whether the first minutes are too hard. Also for a balance check of GameEconomy.json against stated targets.
argument-hint: "[economy | difficulty | check [save]]"
---

# game-balance

Three modes. `economy` writes `design/economy.md`, `difficulty` writes `design/difficulty.md`, `check` compares the real data with the targets in those files and reports. Only `check save` (or "write it down") writes `qa/balance-<date>.md`. Nothing else is written.

**Never invent a target.** A target comes from the user, from `design/brief.md` (`Session length`, `Revenue`) or from a filled template. If there is none, say so and ask, or leave the cell as `(unset)`.

## Where the data is

1. `Assets/_Project/Compass/Resources/GameEconomy.json` (optional): currency, boosters, extras (`supply`, `wheel`, `login`), `shop`. Field meanings: [economy-model](references/economy-model.md).
2. Tuning assets of the game (ScriptableObjects or config classes: speeds, spawn rates, lives, level data), if the project has them.
3. `design/brief.md`, `design/economy.md`, `design/difficulty.md`.

No file and no stated numbers: say "nothing to judge yet", offer the template. Do not estimate.

## Mode: economy

Fill the template in [economy-model](references/economy-model.md) into `design/economy.md`. Values that exist in `GameEconomy.json` are copied, not re-invented; targets are the user's words or `(unset)`. If `design/economy.md` exists, show the changes and ask before overwriting.

## Mode: difficulty

Fill the template in [difficulty-curve](references/difficulty-curve.md) into `design/difficulty.md`. Session length comes from `design/brief.md`. Levels, speeds and lives come from the tuning assets; a value you cannot find stays `(unset)`.

## Mode: check

Read the data and the targets, then follow this order.

**1. Facts that need no target.** Report only what the file proves:
- a booster has a `price` but the file lists no way to get currency: no `supply` with `freeCoins` above 0 or ad rows, no wheel slice or login day with `coins`, no shop row with `coins`. A game's own code (level rewards via `economy.Earn`) may earn it: say the file shows no source and ask, do not call the price unreachable;
- a currency source (`supply`, wheel coins, login coins) in a file where no booster has a `price` and there is no custom extra: nothing to spend on;
- a `shop` row with no `coins` and no `boosters` that is not `remove_ads`;
- a booster with `start` 0 and no way to get it (no price reachable, not in a shop row, not a wheel or login reward).

**2. Compare with targets.** For every value in the template that has a stated target, write the value, the target, and `within` or `outside`. A value without a target is listed as "no stated range, not judged" and never counts against the verdict. Do not guess what is typical.

**3. Fairness rules**, checked against the data:
- No pay-to-win: no shop row sells a power the free player cannot also earn with the currency or a free source. A booster only in `shop` rows and nowhere else is a finding.
- Rewarded ads give currency only through an extra (`supply.adCoins`, `wheel.adSpinsPerDay`, a custom extra). A rewarded ad has a daily cap in the template's code (not in the file); report the file's per-day ad exposure (`adCoins` rows plus `adSpinsPerDay`) and compare it with a stated limit, if any.
- Wheel odds are visible: the template's "i" button lists every slice's odds. A game that replaced the wheel with its own code: check its odds are shown.
- No timer pressure on essential items: `supply.freeHours` and countdowns apply to extras, never to something the player needs to continue. A "limited time" label on a shop row (`tag` is a discount percent) must not be the only way to get an item the game needs.

**4. Verdict**, exactly one:
- `NOT ASSESSED — NO DATA`: no `GameEconomy.json`, no tuning data, or no value has a target. Say what is missing in one line.
- `UNBALANCED`: one or more outside-target values, or one or more fairness rule broken, and the gap is larger than the target's own width.
- `CONCERNS`: any smaller outside-target gap, or any fact from step 1.
- `BALANCED`: at least one value had a target, all are within, no fact from step 1, no fairness finding.

The verdict is the worst one that applies. Two agents with the same data must reach the same one.

## Output

```markdown
# Balance check <date>
**Verdict:** <one of the four>
## Facts from the data
## Against targets
| Value | Now | Target | Result |
## Not judged
- <value>: no stated range, not judged
## Fairness
## What to change first (at most 3, each tied to a value)
```

Report findings in the conversation; write the file only for `check save`.

## Boundaries

Mobile session numbers only: minutes per session, runs to the first purchase, ad rows per day. No live-service measures. Do not edit `GameEconomy.json` or any game file; propose the change and let the user make it (or ask the compass planner to rewrite the file).
