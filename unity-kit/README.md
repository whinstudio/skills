# unity-kit

Compass's rules for the code step of a prompt-made Unity game (spec: Compass
`docs/superpowers/specs/2026-10-17-istemden-oyun-design.md` §6). Compass copies it into every new game:

| File | Lands at | Notes |
|---|---|---|
| `CLAUDE.md` | appended to the project's `CLAUDE.md` | rules for the agent |
| `settings.json` | `.claude/settings.json` | long Bash timeout for Unity, no network |
| `compass-unity` | `./compass-unity` (executable) | `@UNITY@` is replaced with the Unity editor path |
| `CompassAutoPlay.cs` | `Assets/_Project/Compass/CompassAutoPlay.cs` | the auto-play switch; do not edit in projects |
| `materials/*.mat` | `Assets/_Project/Resources/CompassMaterials/` | URP Lit, Unlit, Particles/Unlit (copied from URP's `Runtime/Materials`); the only way game code gets a shader — `Shader.Find` returns null on device |

`kit.json` `version` must match Compass's `UnityKit.VERSION` (2). Edit here, not in Compass: Compass pulls this repo
before every run.
