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
| `CompassUiShotTests.cs` | `Assets/_Project/Tests/PlayMode/Compass/CompassUiShotTests.cs` | explicit PlayMode test that renders the dressed UI screens for the design review (v7) |

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
`CompassAutoPlay` by name because the PlayMode test assembly cannot reference Assembly-CSharp. It draws the camera as
the game sized it (no rescale: games fit their zoom to `Screen`) three times, 2 s apart from 4 s after the game scene
opens, and keeps the frame with the most colours, so a floor change or fade does not end up as the background.

`CompassUiShotTests` is `[Explicit]` too; Compass runs it alone with `-testCategory CompassUiShot -compassShotDir
<folder> -compassShotSize <w>x<h> [-compassShotLanguage <code>]` (without `-nographics`). With AutoPlay off it opens
the menu and draws `ui-settings`, `ui-paywall` and `ui-economy` (the last two are skipped when the game has no
purchases or no economy window), then with AutoPlay on (the menu's first game is started like its Play button when the
AutoPlayer has not opened the game scene 8 s after the menu) the game scene's `ui-hud`, `ui-pause` and the end card
(`ui-level-complete` in Levels mode, else `ui-game-over`, with `Time.timeScale` 0 so the AutoPlayer stays still). It
selects the language through the template's `LanguageSelector` (so the settings' language row shows it too; the stored
`lang.code` choice is restored afterwards), hides the network inspector's overlay while it draws, closes a paywall or
economy window left open before each screen (and the paywall and economy window right after their own shot), and
counts a screen as failed when its view (settings panel, pause panel, end card) is not open. Each screen is drawn with
the overlay canvases moved onto the camera, so the world stays behind the HUD. Game types (`MenuView`, `PauseView`,
`ILocalizer`, `IPaywall`, `IEconomyWindows`, `IGameShell`) are found by simple name, as generated games rename the
template's namespaces; services are resolved from the loaded `LifetimeScope`s. It logs one `COMPASS_UI_SHOT <name>
ok`, `skipped: <reason>` or `failed: <reason>` line per screen and fails only when `settings`, `hud`, `pause` or the
end card failed.

`kit.json` `version` must be one Compass supports (3, 4, 5, 6 or 7). Edit here, not in Compass: Compass pulls this repo
before every run.

## Versions

- v7: `CompassUiShotTests` (UI screen shots for the design review); requires Compass with the Part 3 PR of the game UI atmosphere plan.
- v6: Economy rules in `CLAUDE.md` (currency, boosters, custom extras, `CompassBooster` and `CompassEconomy` tests), the shell owns the interstitial, the leaderboard button goes through `IMenuSideButtons`; requires Compass with the Task 8 PR of the game economy plan (unity-kit v6 support).
- v5: `CompassBranding`, `CompassMenuShotTests`, importer `folders`/`borders`/Branding; requires Compass with the Task 8 PR of the game menus plan (unity-kit v5 support).
- v4: `CompassArtImporter`, Art rules in `CLAUDE.md`; requires Compass with unity-kit v4 support (whinstudio/Compass#23).
- v3: materials, UI kit, game shell, presentation rig and juice come from the template.
