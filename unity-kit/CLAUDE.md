<!-- compass-unity-kit -->
# Compass rules for this Unity game

You write the game described in the prompt into this Unity project. Compass made the project from the blank
template, installed these rules, imported it once in Unity and committed it. There is no internet and there are no
art or audio files except the synthesized sounds in `Assets/_Project/Audio`.

## The template

- Scenes: Boot → Menu → Game. Boot runs the boot steps and loads Menu; Menu logs `CMPOSE_BOOT menu-ready` and
  opens the game scene from its play button. Keep that flow and that log line.
- Dependency injection is VContainer: the root scope is `Assets/_Project/Core/DI/RootInstaller.cs`; scenes have
  their own `LifetimeScope`. Register new services there; do not use singletons or `FindObjectOfType`.
- Async is UniTask (`UniTask`, `.Forget()`), not coroutines for new code.
- Feature code lives in `Assets/_Project/Features/<Module>/` with its own assembly definition like the existing
  ones. Read two existing features before adding one.
- Deep links: `DeepLinkRouter.Register(path, handler)` in the root scope; `menu` and `game` are reserved.

## Hard rules

- Build the game scene **in code**: a bootstrap `MonoBehaviour` in the existing game scene creates every object
  at runtime. Never hand-edit `.unity`, `.prefab`, `.asset` or `ProjectSettings/*` files, and never write `.meta`
  files: Unity creates them on import.
- Input is the Input System (`UnityEngine.InputSystem`), touch first (`Touchscreen`, with `Mouse` as the editor
  fallback). No `UnityEngine.Input` legacy calls.
- No `GameObject.Find`, `SendMessage` or reflection tricks.
- Visuals come from the plan's palette and shape language, drawn in code: 2D uses sprites made at runtime
  (`Texture2D` → `Sprite.Create`, simple shapes, solid colours); 3D uses primitives with a URP Lit material
  (`Shader.Find("Universal Render Pipeline/Lit")`). Keep contrast readable.
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
`- [ ]` to `- [x]` and add one line under it with what was built. Do not rewrite the other milestones.

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
