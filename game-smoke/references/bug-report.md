# Bug report format

One entry per `FAIL` in the smoke report. Facts only: write `NOT ASSESSED` for anything you did not
observe, and do not propose a fix.

```markdown
### <Concise title: what breaks, where>

- **Severity**: S1 crash or no launch | S2 feature or screen unusable | S3 wrong but usable | S4 cosmetic
- **Category**: Gameplay | UI | Audio | Visual | Performance | Crash | Network
- **Check**: <the row of the report that failed>
- **Frequency**: Always | Often | Sometimes | Rare | seen once
- **Regression**: Yes | No | NOT ASSESSED

**Environment**: commit <short sha>; <Android serial, model, API | iOS device, runtime>; scene or screen <name>

**Steps**
1. <Exact step, with the command when it was a command>
2. <Exact step>

**Expected**: <what should happen>
**Actual**: <what happened>

**Evidence**
- Screenshot: qa/evidence/<platform>/<run>-NN-<what>.png
- Log: <the relevant lines, a few at most, or the log's path>

**Likely area**: <file or system, only when the evidence points to it; else NOT ASSESSED>
```
