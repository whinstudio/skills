---
name: cmp-design-rules
description: Use when choosing colours, type, spacing, motion or interface copy in this Compose Multiplatform app and no design board or mockup dictates them, when a screen or the whole app looks generic or must be restyled, or when asked to review how the app looks.
---

# Design rules

A generated app starts black and white, on the system font, with no motion. These rules are for
the choices that replace that. A provided design always wins (`cmp-design-to-code`). Code rules
are in `cmp-code-rules`.

Paths are under `core/designsystem/src/commonMain/kotlin/<package>/core/designsystem/`. Without
Theming there is no `KtTheme`: `shared/.../AppTheme.kt` is a plain `MaterialTheme`; put the scheme,
typography and shapes there and read only `MaterialTheme` (`cmp-design-to-code`, section 4).

## 1. State the read first

Before picking a value, write one line:

`Reading this as: <kind of app>, <audience>, <one or two mood words>, <brand inputs or none>.`

Colours, logo and type the app already has are input. If the read is truly ambiguous, ask one
question; in a headless run pick one and list it under `Assumptions`. A colour with no reason
behind it is the default you are trying to avoid.

What makes an app look generated: Material's stock lilac showing through, one neutral font doing
every job, the accent on everything, every row a rounded card, cards inside cards, shadows as the
only depth, gradients where a flat colour would do, an emoji or a text glyph (`"!"`) as a control
icon. Draw icons with `KtIcon` (the language picker's flag rows in `cmp-code-rules` are the one
exception).

## 2. Tokens: three tiers

| Tier | What | Where |
|---|---|---|
| Primitive | hex values, ramps | only `theme/CustomColorsPalette.kt`: `OnLightColorsPalette`, `OnDarkColorsPalette` |
| Semantic | `MaterialTheme.colorScheme.*`, `.typography.*`, `.shapes.*` | mapped in `colorSchemeFor` and passed to `MaterialTheme(...)` in `theme/KtTheme.kt` |
| Component | `ErrorContent`, `KtSearchBar`, `KtText`, `KtIcon`; the palette's `toggle*` and `textField*` fields | `component/` |

A screen reads, in this order:

1. `MaterialTheme.colorScheme.x`.
2. `LocalColorsPalette.current.x`, only for a role Material does not have.
3. Never `Color(0x...)`, `Color.White` or a `private val Accent` under `ui/`. A file-level colour has
   no dark value, so it is wrong in one of the two modes.

What the template does and what that means for a restyle:

- `colorSchemeFor` maps eight roles (`primary`, `onPrimary`, `background`, `onBackground`, `surface`,
  `onSurface`, `onSurfaceVariant`, `outline`). Everything else is the stock lilac baseline:
  `FilledTonalButton` reads `secondaryContainer`, `Card` reads `surfaceContainerHighest`,
  `NavigationBar` reads `surfaceContainer`. Map a role in `colorSchemeFor` before using a component
  that reads it. Do not paint over it with `colors = ...` at the call site.
- `ColorSchemeForTest` pins the mapping, including that `error` and `secondary` stay on the baseline
  and `primary` is `tintBlack`. Change the test in the same commit as the mapping, or `allTests` fails.
- `primary` is `tintBlack`, which also tints icons on every screen. Do not recolour `tintBlack` to
  get an accent. Add an `accent` and `onAccent` field and map `primary` and `onPrimary` to them.
- Palette fields default to `Color.Unspecified`, so a field set in one palette only still compiles.
  Set every new field in both.
- Existing names are literal (`textBlack` is white in dark mode). Leave them; a rename touches every
  screen and changes nothing on it. Name new fields for their job (`accent`, `surfaceRaised`).
- `KtTheme` passes no typography or shapes. Add `typography =` and `shapes =` to its `MaterialTheme` call.

Spacing and shape:

- Spacing is on a 4 dp scale: 4, 8, 12, 16, 24, 32, 48. A value used on more than one screen becomes
  a token in `theme/`; the template has none yet. compass-kit's detekt exempts `theme/` from
  `MagicNumber`; under the template's own `detekt/detekt.yml`, declare the numbers as `const val`.
- Radii are `MaterialTheme.shapes.*`, two to four values for the whole app. No `RoundedCornerShape(n.dp)`
  under `ui/`.
- Depth comes from tonal surfaces and hairlines first. A shadow is for something that floats. Three
  elevation levels at most.

## 3. Colour

**60-30-10.** 60% neutrals (background, two to four surfaces, three text steps), one family, warm or
cool. 30% structure (`outline`, `outlineVariant`, dividers): a tinted neutral, not a colour. 10%
accent: one saturated `primary` with a job.

- The accent marks the primary action and the current selection. Count it per screen: past about
  four places it stops pointing at anything. Not the avatar ring and the header and the star and the
  links and the spinner.
- A second accent needs its own job and stays under about 2% of the screen. `error` is for status,
  never decoration.
- Stepped tints of the neutral give depth without new colours. `surface` equal to `background` (the
  template's mapping) leaves a card nothing to sit on.
- Build ramps in OKLCH, not by mixing hex values: [references/color.md](references/color.md).

**Dark theme** is a second mapping, not an inversion. Surfaces get lighter as they rise; the accent
moves one or two ramp steps lighter; contrast is computed again. Dark is not automatically premium,
and default navy is a stock look. Every colour change goes into both palettes, and a changed
background also goes into `window_background` in `androidApp/src/main/res/values/themes.xml` and
`values-night/themes.xml`.

## 4. Contrast

| Element | Minimum (WCAG 2.2 AA) |
|---|---|
| Normal text | 4.5:1 |
| Large text (24 sp and up, or 18.66 sp bold and up) | 3:1 |
| Icons, input edges, control boundaries | 3:1 against what is next to them |
| Focus indicator | 3:1 against what is next to it |

Compute every pair; a ratio cannot be judged by eye. On the template, grey that looks weak in dark
mode passes and grey that looks fine in light mode fails: `textGray` is 5.02:1 on dark and 3.05:1
on light. A warm orange such as `#E8590C` with white text is 3.58:1, so it fails as a button label.
Formula, a Kotlin check and a test: [references/color.md](references/color.md). Check both modes,
and a semi-transparent colour only after compositing it on its real background.

## 5. Touch and states

- Targets are at least 48 dp, which also covers iOS's 44 pt. Use `IconButton` or
  `Modifier.minimumInteractiveComponentSize()`. Order matters: in `padding(16.dp).size(24.dp).clickable`
  the target is 24 dp.
- There is no hover. Pressed feedback is Material's ripple; never pass `indication = null` on something
  tappable. For a custom pressed look use `interactionSource.collectIsPressedAsState()` and change one
  property.
- Focus still happens (hardware keyboards, Switch Access, text fields). Focused must differ visibly
  from unfocused, at 3:1. `collectIsFocusedAsState()` gives you the state.
- Disabled uses Material's own disabled colours. It must look inert, not merely grey.
- An error is never colour alone: text, and an icon where there is room.

## 6. Typography

- Put the scale into `Typography(...)` and read `MaterialTheme.typography.x`. No `fontSize = 18.sp` at
  a call site. Text goes through `KtText`, not bare `Text`, so one change reaches every screen.
- **`KtText` defaults to `fontWeight = FontWeight.Normal`, and that beats the weight in `style`.** Pass
  `fontWeight = null` with a style:
  `KtText(text = title, style = MaterialTheme.typography.titleLarge, fontWeight = null)`.
- Two families at most, with a reason. A display face needs a bundled font; how to add one without it
  silently falling back on Android is in `cmp-design-to-code`, section 4. No font file available: stay
  on the system font, build the hierarchy from size and weight, and say so.

| Role | Size / line height | Weight |
|---|---|---|
| `headlineSmall` (screen title) | 24 / 32 | the family's display weight |
| `titleMedium` (section, row title) | 16 to 20 / 24 to 28 | 500 to 600 |
| `bodyLarge` (reading text) | 16 / 24 | 400 |
| `bodyMedium` (secondary text) | 14 / 20 | 400 |
| `labelMedium` (metadata) | 12 to 13 / 16 | 500 |

- Nothing under 12 sp. Above 24 sp only where that value is the point of the screen (a first-run
  title, a balance, a score).
- Each step down shrinks in size and weight together. Five sizes on one screen is no hierarchy; three
  weights is the limit.
- Line heights are multiples of 4. Display letter spacing about `(-0.02).em`; uppercase labels `0.08.em`
  to `0.2.em`; body 0.
- Never `FontWeight.Bold` on a family that ships only 400: Compose fakes it.
- Sizes stay in `sp` and text boxes use `heightIn(min = ...)` so large fonts fit.

## 7. Motion

Motion explains what happened. If you cannot say in one sentence what an animation explains, delete it.

| Token | Compose value | For |
|---|---|---|
| Fast, 100 to 150 ms | `tween(120, easing = FastOutSlowInEasing)` | pressed, focus, colour change |
| Base, 200 to 300 ms | `tween(240, easing = FastOutSlowInEasing)` | toggle, small entrance, loading to content |
| Slow, 400 to 500 ms | `tween(450, easing = CubicBezierEasing(0.22f, 1f, 0.36f, 1f))` | dialog, list to detail |
| Exit, shorter than its entrance | `tween(120, easing = FastOutLinearInEasing)` | anything leaving |
| Interruptible | `spring()` (no bounce; what `animate*AsState` uses) | a position or scale that can reverse mid-flight |
| Playful, once per element | `spring(dampingRatio = Spring.DampingRatioLowBouncy)` | only when the read in section 1 is playful |

Values used on more than one screen go in `theme/`. `LinearEasing` is for progress only.

- One value: `animateColorAsState`, `animateFloatAsState`. A swap between states: `AnimatedContent` with
  your own `transitionSpec`; the default scales from 0.92, past the limit below. Show or hide:
  `AnimatedVisibility`. Reorder: `Modifier.animateItem()`.
- Move alpha, translation and scale through `graphicsLayer { }`. Do not animate size or padding, except
  `animateContentSize()` on a deliberate expand.
- One property per interaction, not scale and colour and position together.
- Reveal distance is at most 20 dp, and the lambda of `slideInVertically` is in pixels: convert with
  `with(density) { 12.dp.roundToPx() }`. `12.dp.value.toInt()` is a different distance on every screen density.
- Scale entrances start at 0.96 or higher and belong to dialogs.
- Stagger is two or three stages, 60 to 120 ms apart, once, on a screen's first appearance.
- At most one looping thing per screen, a loader. It must not move the layout (`cmp-code-rules`, section 8).

Do not animate: list content that refills as the user types or refreshes (item entrances replay on
every keystroke); controls Material already animates (`Switch`, ripple); a change nobody can see; anything
longer than about 1.5 s; every element of a screen at once.

**Reduced motion.** Compose Multiplatform has no common `isReduceMotionEnabled`, and you do not need one.
Both platforms feed the system setting into `MotionDurationScale`: iOS Reduce Motion sets it to 0, and so
does Android's Remove animations. At 0, `animate*AsState`, `tween`, `spring`, `AnimatedContent`,
`AnimatedVisibility`, `Crossfade`, `animateItem` and `rememberInfiniteTransition` end on the next frame,
with no code from you. So:

- The end state must be correct by itself. Nothing may depend on an animation having played.
- A spinner stops moving, so a long load also says so in text.
- Not covered: sequences built on `delay()` and hand-written `withFrameNanos` loops. There, check
  `coroutineContext[MotionDurationScale]?.scaleFactor == 0f` and skip the motion.

## 8. Copy

Text goes through the language system: `LocalStringResources.current.x`, a new property in
`StringResourcesUiModel` and in every language object (`cmp-code-rules`, section 11). Nothing hard-coded
in a composable, and reuse what exists (`retry`).

**Errors: what happened, why, the fix.** Use `strings.errorMessage(error)`, which keeps the error type;
a fixed message tells someone to check their connection when the server failed. Restyle `ErrorContent`
rather than adding a second error composable.

| | |
|---|---|
| Good | "No internet connection. Check your connection and try again." |
| Bad | "Error 500, please try again later." |

**Empty states: name it, say why, give the next action.** The action is one button, or a pointer to the
control already on screen. An empty state with neither is a dead end.

| | |
|---|---|
| Good | "No favourites yet" / "Tap the star on a profile to keep it here." |
| Bad | "No data" |

- Buttons say the action ("Save changes", "Delete project"), never "OK" or "Submit". A destructive
  action names what goes.
- Progress says what is happening ("Uploading 3 of 8"). Never blame the user.
- Write for translation: no idioms, no variable in the middle of a sentence ("Friends: 12").
  No "just", "simply", "easily".

## 9. Review

Do not change code in this pass. Report, then fix what is asked.

1. Read `theme/`, then list the screens: `feature/*/presentation/**/ui/`.
2. Run each pattern with `grep -rnE --include='*.kt' --exclude-dir=build <pattern> feature shared core/designsystem`,
   and ignore hits in `theme/`, `icon/`, imports and tests:
   - `Color\((0x|color =)|Color\.(White|Black|Red|Gray)`: raw colour, no dark value.
   - `[0-9]\.sp\b`: type size outside the scale.
   - `\bKtText\(`: read each; `style =` without `fontWeight = null` loses the style's weight.
   - `\bText\(`: bypasses `KtText`.
   - `RoundedCornerShape\(`: shape outside the theme.
   - `(text|label|title) = "[^"]|\bText\("`: hard-coded text.
   - `\.clickable`: read each with its `size` and `padding`; a target under 48 dp.
   - `indication = null`: no pressed state.
   - `animate|AnimatedContent|AnimatedVisibility|Crossfade|InfiniteTransition`: check against section 7.
     None on a screen that changes state is also a finding.
   - `delay\(`: read each; only motion counts, a search debounce does not.
3. Contrast: list every text and background pair the screens use, in both palettes, and compute each.
   Write the ratio in the finding.
4. States: every screen that loads has loading, empty, error and content. The error text follows the
   error type. The empty state has a next action.
5. Per screen: count accent uses, type sizes and nested cards; look for stock lilac from an unmapped
   role (section 2).
6. If you can run the app, screenshot each screen in light and dark and add what the code does not show.
   If you cannot, write `Not seen on a device` under the findings.

End with this list, most severe first. A cause in the theme is one finding at its theme line, not one per
call site.

```
| # | Severity | Location | Rule | Finding | Fix |
|---|---|---|---|---|---|
| 1 | High | core/designsystem/.../theme/CustomColorsPalette.kt:32 | Contrast | textGray #8B959E on #FFFFFF is 3.05:1, needs 4.5:1 | Darken to pass; #6B7580 is 4.69:1 |
```

| Severity | Means |
|---|---|
| High | Fails a number or loses information: contrast under the minimum, target under 48 dp, hard-coded text, a raw colour with no dark value, a missing state, an error shown as empty |
| Medium | Breaks the system: raw type, shape or spacing where a token exists, a stock role showing, motion against section 7 |
| Low | Polish: hierarchy, rhythm, copy tone |

## Done when

- The one-line read is written and every choice traces to it.
- No raw colour, type size or shape under `ui/`, and no hard-coded text.
- Every text pair is computed in both modes and meets section 4; targets are 48 dp.
- Motion meets section 7, and each animation can be explained in one sentence.
- `ColorSchemeForTest` matches the mapping, and the gates pass (`cmp-gates`).
