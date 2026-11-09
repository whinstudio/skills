# Post-mortem

Use after a launch, an update or an abandoned game, when the user asks for a post-mortem or a
retrospective. Short on purpose: one page, honest, with three lessons.

The only file written is `design/post-mortem.md`; when it exists, append `-2`, `-3`. Do not commit it.

## Ask first

Two questions at most, one at a time, only for what the files do not answer: what the goal was
(read `design/brief.md` first) and what the result was (downloads, rating, crash rate, revenue,
or "never shipped"). Do not invent numbers. A figure the user did not give is "unknown".

## Template

```markdown
# Post-mortem: <game name>, <date>

Period: <start> to <end> | Version: <shipped version or "not shipped">

## Goal vs result

| Goal | Result |
|---|---|
| <goal from the brief or the user> | <what happened, with the number when known> |

## What went well

- <what> - why it worked, so it can be repeated

## What went badly

- <what> - the cause, the cost, how to avoid it next time

## Three lessons

1. <lesson> - how it changes the next game
2. <lesson>
3. <lesson>
```

Exactly three lessons. Two entries under each of "went well" and "went badly" are usually enough;
more only when the user supplied them. No sprint, timeline, team, metrics or action-item sections.
