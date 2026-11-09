---
name: game-brief
description: Use when someone is starting a Unity 6 mobile game or asks what to prepare before code, wants a game brief, pitch, MVP list or pillars, or asks whether a game's scope has crept or whether a new feature still fits.
argument-hint: "[brief <idea> | scope-check]"
---

# game-brief

Two modes. `brief` writes **one file, `design/brief.md`, that fits one screen**. `scope-check` compares the project with that file and writes nothing. Pick the mode from the argument or the request; "should we add X" or "has scope crept" means `scope-check`.

## Mode: brief

The output is the filled template below and nothing else: no other documents, no analysis before or after it. Tell the user the file path and the three `(guess)` markers you are least sure of.

**Where.** Normally `design/brief.md` (create `design/` if missing). If there is no Unity project yet, write `brief.md` in the current folder and tell the user to move it to `design/brief.md` after `game-new-project`. If `design/brief.md` already exists, show what would change and ask before overwriting.

**Asking.** From the request, fill everything you can. Ask only what cannot be inferred, in one short message with at most four questions. If the genre or the camera (2D or 3D) cannot be inferred, ask about it even when the user says "go ahead". Everything else still open becomes a guess marked `(guess)` in the file so the user can correct it. Do not ask for a field you can reasonably propose.

**Template** for the brief (at most 60 lines):

```markdown
# <Working title>

**Pitch:** <one sentence>

## Core loop
- <do> -> <get> -> <why again> (2-4 bullets)

## Player goal and fail
<what the player wants; how a run ends. 1-2 lines, testable>

## MVP (7 items at most)
- <feature without which this is not the game>

## Out of scope (5 items at most)
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
**Reference game:** <game> - the MVP keeps about <N>% of it: <which part> | none (drop the percentage)

## Mobile
**Orientation:** portrait | landscape
**One-handed:** yes | no
**Session length:** <e.g. 2-3 minutes>
**Revenue:** ads | IAP | none | undecided
**Stores:** Google Play | App Store | both
```

Rules for the fields:
- `**Orientation:**` is exactly `portrait` or `landscape`, on its own line, never with a `(guess)` marker, because `game-smoke` reads it. A guessed orientation goes in the guesses you report to the user.
- A pillar is falsifiable and removes options ("one finger, never two" not "fun controls").
- Each build-order step is something the player can try; the first one proves the loop is fun.
- The reference game percentage is the honest size of the MVP against a shipped game.
- If a field needs a second paragraph, cut it; that is a design document, not a brief.

## Mode: scope check

Read-only. The MVP list in `design/brief.md` is the baseline.

1. No `design/brief.md`, or a brief with no MVP items: report `NOT ASSESSED` and stop.
2. Gather what the project now contains: `git log` since the brief's last change (the brief's own commit is `git log -1 --format=%H -- design/brief.md`; empty output means it has none, so use all history), `TODO`/`FIXME` comments, and the feature folders, scenes and scripts present. Features that are already in the game's first generated commit (`git rev-list --max-parents=0 HEAD`) are the starting point, not work: do not count them.
   If there is no git history, the feature folders and scripts the template ships are the starting point. If the first commit is not the generated one (squashed history, or the project was added to an existing repo), use the commit the user names or the earliest commit that adds the Unity project. Say which baseline you used in the report.
3. Map each piece of work to the brief. An item is one player-visible feature or system; several commits or files for the same feature count once. A TODO counts only if it names new scope. Work that serves an MVP item without adding a new player-visible capability is not added. Count **added**: items in neither the MVP nor a reasonable part of it, or that touch an Out of scope item. Count **removed**: MVP items dropped or deferred. An MVP item that files cannot prove (for example a timing or pacing rule) is listed as "not verifiable" and counts as neither present nor removed.
4. Scope change = (added + removed) / number of MVP items in the brief.

| Scope change | Verdict |
|---|---|
| 10% or less | `PASS` |
| above 10%, up to 25% | `CONCERNS` |
| above 25% | `FAIL` |

Report: verdict, the baseline count, each added and removed item with the commit or file that shows it, and one recommendation per added item (cut, defer, or swap for an MVP item). If the user wants the scope change to stay, the brief is edited with their say-so, then re-checked.
