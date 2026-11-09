# Difficulty template

Write this into `design/difficulty.md`. One screen; `(unset)` where nobody has decided. Session length comes from `design/brief.md`.

```markdown
# Difficulty: <working title>
**Session length (from the brief):** <minutes>

## Axes
| Axis | What makes it hard here | Can the player lower it? |
|---|---|---|
| Execution (timing, precision) | | |
| Knowledge (what the player must learn) | | |
| Resource pressure (lives, currency) | | |
| Time pressure (timers, speed) | | |
| Decisions (choices at once) | | |

## First failure
<what causes the first loss, what the player learns from it, how fast they retry, what it costs. Target time: (unset)>

## First feeling of mastery
<the specific beat: what the player does and how the game says "well done". Target time: (unset)>

## Curve per level (or per run for endless games)
| Level or run | Difficulty 1-10 | What is new | Lives or retries | Target win rate |
|---|---|---|---|---|
| 1-3 | | | | (unset) |
| 4-10 | | | | (unset) |
| 11+ | | | | (unset) |

A good curve rises, then eases after a hard point, then rises a little higher. A new mechanic never arrives together with a rise.

## Catch-up help
<what the player gets after repeated failure: an easier retry, a free booster, a skip, a hint. Trigger: (unset)>

## Fit with the session
| Question | Answer |
|---|---|
| Levels or runs that fit one session | |
| Is one failure shorter than a minute to recover from | |
| Does the first session end on a win or a near win | |
```

Fill numbers from the game's tuning assets (speeds, spawn rates, lives, level tables); a number you cannot find stays `(unset)`. Do not use live-service measures; only what one phone session shows.

Check rules for difficulty (linked from SKILL.md, applied when asked to check difficulty): a row with a target is compared (win rate, time to first failure, time to first mastery); a row without is "no stated range, not judged". A new mechanic introduced in the same level as a rise of two or more points is a fact worth reporting.
