---
name: game-brief
description: Use when someone is starting a Unity 6 mobile game or asks what to prepare before code, wants a game brief, pitch, MVP list or pillars, or asks whether a game's scope has crept or whether a new feature still fits. Two modes - write the brief, or run a scope check against it.
argument-hint: "[brief <idea> | scope-check]"
---

# game-brief

Two modes. `brief` writes **one file, `design/brief.md`, that fits one screen**. `scope-check` compares the project with that file and writes nothing. Pick the mode from the argument or the request; "should we add X" or "has scope crept" means `scope-check`.

## Mode: brief

The output is the filled template below and nothing else: no other documents, no analysis before or after it. Tell the user the file path and the three guesses you are least sure of.

**Asking.** From the request, fill everything you can. Ask only what cannot be inferred, in one short message with at most four questions. For anything still open, write a guess marked `(guess)` in the file so the user can correct it. Do not ask for a field you can reasonably propose.

**Template** for `design/brief.md` (create `design/` if missing):

```markdown
# <Working title>

**Pitch:** <one sentence>

## Core loop
- <do> -> <get> -> <why again> (2-4 bullets)

## Player goal and fail
<what the player wants; how a run ends. 1-2 lines, testable>

## MVP (7 items at most)
- <feature without which this is not the game>

## Out of scope
- <specific thing not being built>

## Build order
1. <the riskiest or most core-fun item first>

## Pillars
1. <pillar, one line>
2. <pillar, one line>
3. <pillar, one line>
- **Anti-pillar:** NOT <something the team might plausibly want>

**For whom / feel:** <player and the feeling, one line>
**Art direction:** <one line>
**Reference game:** <game> - the MVP keeps about <N>% of it: <which part>

## Mobile
**Orientation:** portrait
**One-handed:** yes
**Session length:** <e.g. 2-3 minutes>
**Revenue:** ads | IAP | none
**Stores:** Google Play, App Store
```

Rules for the fields:
- `**Orientation:**` is exactly `portrait` or `landscape`, on its own line. `game-smoke` reads it.
- A pillar is falsifiable and removes options ("one finger, never two" not "fun controls").
- Each build-order step is something the player can try; the first one proves the loop is fun.
- The reference game percentage is the honest size of the MVP against a shipped game.
- If a field needs a second paragraph, cut it; that is a design document, not a brief.

## Mode: scope check

Read-only. The MVP list in `design/brief.md` is the baseline.

1. No `design/brief.md`: report `NOT ASSESSED` and stop.
2. Gather what the project now contains: `git log` since the brief's last change, `TODO`/`FIXME` comments, and the feature folders, scenes and scripts present.
3. Map each piece of work to the brief. Count **added**: work that is in neither the MVP nor a reasonable part of it, or that touches an Out of scope item. Count **removed**: MVP items dropped or deferred.
4. Net change = (added + removed) / MVP item count.

| Net change | Verdict |
|---|---|
| 10% or less | `PASS` |
| above 10%, up to 25% | `CONCERNS` |
| above 25% | `FAIL` |

Report: verdict, the baseline count, each added and removed item with the commit or file that shows it, and one recommendation per added item (cut, defer, or swap for an MVP item). If the user wants the scope change to stay, the brief is edited with their say-so, then re-checked.
