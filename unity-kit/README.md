# unity-kit

Compass's rules for the code step of a prompt-made Unity game (spec: Compass
`docs/superpowers/specs/2026-10-17-istemden-oyun-design.md` §6). Compass copies it into every new game:

| File | Lands at | Notes |
|---|---|---|
| `CLAUDE.md` | appended to the project's `CLAUDE.md` | rules for the agent |
| `settings.json` | `.claude/settings.json` | long Bash timeout for Unity, no network |
| `compass-unity` | `./compass-unity` (executable) | `@UNITY@` is replaced with the Unity editor path |
| `CompassAutoPlay.cs` | `Assets/_Project/Compass/CompassAutoPlay.cs` | the auto-play switch; do not edit in projects |
| `CompassArtImporter.cs` | `Assets/_Project/Compass/Editor/CompassArtImporter.cs` | imports `Resources/Art/` and `Resources/Branding/` as sprites, the app icons as textures |
| `CompassBranding.cs` | `Assets/_Project/Compass/Editor/CompassBranding.cs` | writes icons and splash into the player settings (v5) |
| `CompassMenuShotTests.cs` | `Assets/_Project/Tests/PlayMode/Compass/CompassMenuShotTests.cs` | explicit PlayMode test that renders the menu background (v5) |

Materials, the UI kit, the game shell, the presentation rig and the juice helpers come from the Unity game
template itself (since v3); the kit only tells the agent to use them.

For games with art, Compass also stages the chosen Kenney packs in `.compass/art/` (with `INDEX.md`) and writes
`Assets/_Project/Compass/compass-art.json` (`{"pixelsPerUnit":16,"pixel":true,"packs":["tiny-town"]}`), which
`CompassArtImporter` reads; without it sprites import at 100 pixels per unit with bilinear filtering. Since v5 the
file may also carry `folders` (`{"<slug>":{"pixelsPerUnit":48,"pixel":true}}`, which wins over the top-level values
for that pack) and `borders` (`{"Art/<slug>/<file>.png":[left,bottom,right,top]}`, keyed under `Resources/`): those
sprites get that nine-slice border and a full-rect mesh, as the template's tiled UI skin needs.

`CompassBranding.Apply` (run by Compass with `-executeMethod`) reads `Assets/_Project/Compass/compass-branding.json`,
sets the default, iOS and Android (adaptive, legacy, round) icons, turns the "Made with Unity" splash off, reads it
back and logs `COMPASS_BRANDING ok` or `COMPASS_BRANDING failed: <reason>` (exit 1). Unity 6 (6000.3) has no public
player setting for the Android 12+ system splash or the iOS launch screen colour: Android draws its system splash
from the adaptive icon, iOS keeps the template's launch screen, and `splashBackground` goes to the Unity splash
background colour only.

`CompassMenuShotTests` is `[Explicit]`, so `./compass-unity play` skips it; Compass runs it alone with
`-testCategory CompassMenuShot -compassShotOut <png> -compassShotSize <w>x<h>` (without `-nographics`). It finds
`CompassAutoPlay` by name because the PlayMode test assembly cannot reference Assembly-CSharp, and scales an
orthographic camera from `Screen.height` to the shot's height, as the pixel-perfect rule in `CLAUDE.md` sizes it.

`kit.json` `version` must be one Compass supports (3, 4 or 5). Edit here, not in Compass: Compass pulls this repo
before every run.

## Versions

- v5: `CompassBranding`, `CompassMenuShotTests`, importer `folders`/`borders`/Branding; requires Compass with the Task 8 PR of the game menus plan (unity-kit v5 support).
- v4: `CompassArtImporter`, Art rules in `CLAUDE.md`; requires Compass with unity-kit v4 support (whinstudio/Compass#23).
- v3: materials, UI kit, game shell, presentation rig and juice come from the template.
