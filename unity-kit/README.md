# unity-kit

Compass's rules for the code step of a prompt-made Unity game (spec: Compass
`docs/superpowers/specs/2026-10-17-istemden-oyun-design.md` §6). Compass copies it into every new game:

| File | Lands at | Notes |
|---|---|---|
| `CLAUDE.md` | appended to the project's `CLAUDE.md` | rules for the agent |
| `settings.json` | `.claude/settings.json` | long Bash timeout for Unity, no network |
| `compass-unity` | `./compass-unity` (executable) | `@UNITY@` is replaced with the Unity editor path |
| `CompassAutoPlay.cs` | `Assets/_Project/Compass/CompassAutoPlay.cs` | the auto-play switch; do not edit in projects |
| `CompassArtImporter.cs` | `Assets/_Project/Compass/Editor/CompassArtImporter.cs` | imports `Resources/Art/` as sprites |

Materials, the UI kit, the game shell, the presentation rig and the juice helpers come from the Unity game
template itself (since v3); the kit only tells the agent to use them.

For games with art, Compass also stages the chosen Kenney packs in `.compass/art/` (with `INDEX.md`) and writes
`Assets/_Project/Compass/compass-art.json` (`{"pixelsPerUnit":16,"pixel":true,"packs":["tiny-town"]}`), which
`CompassArtImporter` reads; without it sprites import at 100 pixels per unit with bilinear filtering.

`kit.json` `version` must match Compass's `UnityKit.VERSION` (4). Edit here, not in Compass: Compass pulls this repo
before every run.

## Versions

- v4: `CompassArtImporter`, Art rules in `CLAUDE.md`; requires Compass with unity-kit v4 support (whinstudio/Compass#23).
- v3: materials, UI kit, game shell, presentation rig and juice come from the template.
