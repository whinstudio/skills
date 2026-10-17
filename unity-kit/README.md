# unity-kit

Compass's rules for the code step of a prompt-made Unity game (spec: Compass
`docs/superpowers/specs/2026-10-17-istemden-oyun-design.md` §6). Compass copies it into every new game:

| File | Lands at | Notes |
|---|---|---|
| `CLAUDE.md` | appended to the project's `CLAUDE.md` | rules for the agent |
| `settings.json` | `.claude/settings.json` | long Bash timeout for Unity, no network |
| `compass-unity` | `./compass-unity` (executable) | `@UNITY@` is replaced with the Unity editor path |
| `CompassAutoPlay.cs` | `Assets/_Project/Compass/CompassAutoPlay.cs` | the auto-play switch; do not edit in projects |

Materials, the UI kit, the game shell, the presentation rig and the juice helpers come from the Unity game
template itself (since v3); the kit only tells the agent to use them.

`kit.json` `version` must match Compass's `UnityKit.VERSION` (3). Edit here, not in Compass: Compass pulls this repo
before every run.
