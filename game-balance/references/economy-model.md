# Economy template and the real file

Write this into `design/economy.md`. Keep it to one screen; `(unset)` where nobody has decided.

```markdown
# Economy: <working title>
**Status:** draft | tuned

## Currency
| Name | Colour | Earned by | Spent on | Cap |
|---|---|---|---|---|
<one currency; the file's currency.name>

## Sources
| Source | Amount | How often | Condition |
|---|---|---|---|
<supply free, supply ad rows, wheel slices, login days, level rewards>

## Sinks
| Sink | Price | Why the player buys |
|---|---|---|
<boosters, shop coin packs do not belong here: they are a source for real money>

## Targets (the user's words; never invented)
| Measure | Target |
|---|---|
| Minutes of play to the first purchase | (unset) |
| Rewarded ads a player is asked to watch per day, at most | (unset) |
| Sessions to afford the dearest booster | (unset) |
| Free spins or free supplies per day | (unset) |

## Price ladder
<boosters and packs from cheapest to dearest, with the amount each costs in minutes of play>

## Ethics limits
- Nothing that changes who can win is sold only for money.
- Wheel odds are shown to the player.
- No countdown on something the player needs to continue.
- Rewarded ads are optional and capped per day.
```

Suggested targets when `design/brief.md` has `Session length` and `Revenue`: ask the user, and offer a starting value marked `(proposal)`. A proposal is not a target until the user accepts it; unattended, it never counts.

## `GameEconomy.json` (version 1)

| Section | Fields |
|---|---|
| `version` | required, the number 1; any other value or a missing one makes the file fail to parse |
| `currency` | `name` (1-24 chars), `color` (`#RRGGBB`), `icon` (optional path) |
| `boosters[]` | `id` (`^[a-z][a-z0-9_]{0,31}$`, unique; the same pattern holds for extra ids and shop row ids), `price` (currency, 1 and up), `start` (given on first launch), `offer` (exactly `preRun` or `inRun`), `icon` |
| `extras[]` | `id`, `kind` (`supply`, `wheel`, `login`, `custom`); at most 3; a ready kind listed exactly when its section exists |
| `supply` | `freeCoins`, `freeHours` (above 0, up to 168), `adCoins[]` (ad rows in unlock order; resets at local midnight) |
| `wheel` | `freeEvery` (1-1000; runs or won levels per free spin), `adSpinsPerDay` (0-100), `slices[]` each with `weight`, optional `coins` (default 0), `booster` and `count` (default 1); a slice needs `coins` above 0 or a `booster` |
| `login` | exactly 7 days, each with optional `coins` (default 0), `booster` and `count`; a missed day restarts at day 1 |
| `shop` (optional; absent is not a finding) | `kind` (`full` or `simple`), `rows[]` (up to 16): `id`, `usd` (store setup only, not read by the game), `coins`, `boosters` (id to count), `tag` (discount percent 1-99) |

Template facts you can rely on: rewarded ads give currency only through an extra; every rewarded ad counts towards a daily cap kept in the template's code; a booster in stock is used at once, otherwise it is offered for currency or for one rewarded ad per booster per run (used at once, never stocked); a shop row that pays nothing is Remove Ads; wheel odds are listed by the "i" button. Every booster needs a name and description string, the currency a name string, and each custom extra a name string, in every language the game ships (en, tr, fr, es, it in the template); `EconomyStringsTests` fails otherwise. A broken file turns the whole economy off, so a file that fails to parse is a finding, not a number to judge.

Wheel odds from the file: a slice's chance is its `weight` divided by the sum of all weights. Expected coins per spin is the sum of `coins` times chance (boosters counted separately).
