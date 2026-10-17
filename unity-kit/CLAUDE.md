<!-- compass-unity-kit -->
# Compass rules for this Unity game

You write the game described in the prompt into this Unity project. Compass made the project from the blank
template, installed these rules, imported it once in Unity and committed it. There is no internet and there are no
art or audio files except the synthesized sounds in `Assets/_Project/Resources/Audio`.

## The template

- Scenes: Boot → Menu → Game. Boot runs the boot steps and loads Menu; Menu logs `CMPOSE_BOOT menu-ready` and
  opens the game scene from its play button. Keep that flow and that log line.
- Dependency injection is VContainer: the root scope is `Assets/_Project/Core/DI/RootInstaller.cs`; scenes have
  their own `LifetimeScope`. Register new services there; do not use singletons or `FindObjectOfType`.
- Async is UniTask (`UniTask`, `.Forget()`), not coroutines for new code.
- Feature code lives in `Assets/_Project/Features/<Module>/` with its own assembly definition like the existing
  ones. Read two existing features before adding one.
- Deep links: `DeepLinkRouter.Register(path, handler)` in the root scope; `menu` and `game` are reserved.

## Template features

`README.md` has one section for each feature this project was made with (between `<!-- cmpose:<flag> -->` markers).
Read the sections that are there and build the game on them:

- **Texts and languages:** no player-visible text in code. Every new text gets a key in your module's string
  tables for every language the game ships, and is shown with `LocalizedText` or `ILocalizer.Get`.
- **Ads:** show an interstitial at a natural break (after a game over; the pacer may skip it). The rewarded ad is the
  shell's Continue (below); do not add another. No banner over the play area. While `CompassAutoPlay.Requested` is
  true, show no interstitial or rewarded ad: it would stop the AutoPlayer.
- **Premium and purchases:** keep the template's paywall and premium flow; premium players see no ads. While
  `CompassAutoPlay.Requested` is true, do not open the paywall.
- **Network and NET:** keep them; add network calls only if the plan asks for them.
- **Leaderboards** (only if the section is there): submit the best score at game over and add a leaderboard
  button to the menu.
- **Save system** (only if the section is there): keep saved values, like the best score, with it.

## Screens, shell and world

The template owns the look. Read the README sections "Look: style family, fonts and the UI kit", "Colours and
themes", "Game shell" and "Game world: presentation and juice" before writing UI or visuals.

- **Screens:** menu, settings, about, paywall and pause are the template's. Do not rebuild, restyle or replace them.
- **In-game UI only through `IGameShell`** (`Kturker.UnityBase.Features.Shell.GameShell`, injected into your
  presenter). Never create your own `Canvas`, buttons, panels or score text.
  - Use the plan's flow: call `Begin(ShellMode.Endless)` or `Begin(ShellMode.Levels)` first.
  - During play: `SetScore`, `SetBest`, `SetCounter`, `Toast(key)` (e.g. `"shell.perfect"`),
    `ShowStartHint` / `HideStartHint`.
  - Endless: `await ShowGameOver(score, best, newBest)` returns an `EndChoice`: `Retry` starts a new run, `Menu`
    loads the menu, `Continue` revives the player.
  - Levels: `CurrentLevel`; on a win `CompleteLevel(level, stars)` and `ShowLevelComplete(level, stars, reward)`
    (`Next` calls `Begin` for the next level, `Menu`); on a loss `ShowLevelFailed(level)` (`Retry`, `Continue`,
    `Menu`). Levels needs the save system: without it the Editor throws `InvalidOperationException`.
  - Continue is offered only when a rewarded ad is ready or the player is premium, once per run; the shell decides.
    Do not count it yourself. The AutoPlay ad rule above still holds.
- **World objects** (namespace `Kturker.UnityBase.Core.Render`): shapes from `RoundedMesh.Box(size, radius)`,
  `.Cylinder(...)`, `.Capsule(...)`; materials from `WorldPalette.Material(index, RenderMaterials.SoftGloss)` or
  `WorldPalette.Material(colour, preset)` with a theme role colour (`theme.Current.Get(ThemeRole.Primary)`). Presets:
  `Lit`, `Matte`, `SoftGloss`, `Glow`, `Unlit`, `ParticlesUnlit`; load one directly with
  `RenderMaterials.Load(preset)` or `Resources.Load<Material>("Materials/<name>")`. 2D games use the same colours
  and materials; sprites made at runtime (`Texture2D` → `Sprite.Create`) are fine for shape only.
- **No hex colours in game code:** no colour constants at all. Every colour comes from `WorldPalette.Color(index)`
  (`WorldPalette.Count` entries) or a theme role. Keep contrast readable.
- **Every player action gets feedback:** a juice helper (`CameraShake.Shake(strength)`,
  `SquashStretch.Play(transform)`, `HitFlash.Flash(renderer)`, `ParticlePresets.Burst(position, colour)`,
  `ParticlePresets.Confetti(position)`, `FloatingText.Spawn(position, text, colour)`) + an `IUiFeedback` haptic
  (`Click()`, `Success()`, `Failure()`, `Impact(HapticStrength)`) + a sound.
- **Keep the presentation rig:** `Assets/_Project/Render/GameRig.prefab` (camera, key/fill/rim lights, the family's
  background, post-processing volume) and `ThemeRig`. Tune them from code if the game needs it; never delete or
  replace them.

## Hard rules

- Build the game scene **in code**: a bootstrap `MonoBehaviour` in the existing game scene creates every object
  at runtime. Never hand-edit `.unity`, `.prefab`, `.asset` or `ProjectSettings/*` files, and never write `.meta`
  files: Unity creates them on import.
- Input is the Input System (`UnityEngine.InputSystem`), touch first (`Touchscreen`, with `Mouse` as the editor
  fallback). No `UnityEngine.Input` legacy calls.
- No `GameObject.Find`, `SendMessage` or reflection tricks.
- Materials: **never** call `Shader.Find` or `new Material(<Shader>)`. Unity strips every shader that no asset
  references, so on the phone `Shader.Find` returns null: objects render magenta and `new Material(null)` throws
  `ArgumentNullException`, while the Editor tests still pass. Get materials only from `WorldPalette` /
  `RenderMaterials` (above). Never edit the template's `.mat` files.
- Sounds: Compass synthesized one WAV per sound event into `Assets/_Project/Resources/Audio/<event>.wav`; load
  them with `Resources.Load<AudioClip>("Audio/<event>")` and play them through one audio service. Never create
  audio files yourself.
- Do not touch `Assets/_Project/Compass/CompassAutoPlay.cs`, `compass-unity`, `.claude/` or `keystore*`.

## AutoPlayer (required)

Compass records videos and screenshots and runs the gameplay test with the game playing itself:

1. Write an `AutoPlayer` component that plays with the plan's controls by a simple rule (e.g. "hop when the next
   gap is above the bird"). It must survive for at least 20 seconds and restart the round after a game over.
2. In the root scope, register the deep link: `router.Register("autoplay", _ => { CompassAutoPlay.Request(); <load
   the game scene the way the menu does>; })`.
3. When the menu becomes ready and `CompassAutoPlay.Requested` is true, open the game scene at once.
4. When the game scene starts and `CompassAutoPlay.Requested` is true, add the `AutoPlayer` and call
   `CompassAutoPlay.LogStarted()` once it plays.

## Gameplay test (required)

`Assets/_Project/Tests/PlayMode/CompassGameplayTests.cs`, class marked `[Category("CompassGameplay")]`, at least
one `[UnityTest]` that loads the game scene with `CompassAutoPlay.ForTests(true)`, lets the AutoPlayer play and
asserts the plan's gameplay check (score, progress, no exception). Reset with `CompassAutoPlay.ForTests(false)`
in `[TearDown]`. Add EditMode tests for the pure game logic (scoring, difficulty) as well.

## ROADMAP.md

Compass wrote `ROADMAP.md` from the plan. Build only the milestone you are asked for. When it is done, change its
`- [ ]` to `- [x]` and add one line under it with what was built. Do not rewrite the other milestones. Make this
change with the Edit tool, not `sed`/`awk` into a temporary file: leave no `*.tmp` files behind.

## Verify

- `./compass-unity check` compiles and runs EditMode tests; `./compass-unity play` runs PlayMode tests. Each
  prints only compiler errors or a test summary. Run them in the foreground; one at a time, never in parallel.
- Exit 75 (`UNITY_LOCKED`) means the owner has the project open in the Unity Editor: stop and say so.
- Finish only when both are green.

## Shell

Besides read-only commands, Bash allows only `./compass-unity`, `cp`, `mkdir`, `sed`, `awk` and `grep`. There is
no network and no script interpreter. The shell starts at the project root: never `cd`. No shell variables, loops,
`$(...)`, backticks, heredocs or `find -exec`. Search with `grep -rn 'text' Assets --include='*.cs'`, list with
`find Assets -name '*.cs'`. Write and change files with the Write and Edit tools.
