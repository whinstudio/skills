---
name: game-look
description: Use when the art of a Unity 6 mobile game must look like one game - new or mismatched characters, backgrounds, icons or UI art, a restyle, or a request to make the visuals consistent or to match a reference image.
---

# Game look

One reference image, one page of rules, every new asset made from both, and a device screenshot
before and after. Without a fixed reference each asset drifts from the last one.

**A visual task is not done without a screenshot.** The editor's Game view does not count. The
screenshot comes from `game-smoke` (step 4). If it returns `Visual: NOT DONE`, this skill's work is
not done either; say so and name the blocker.

Done means all three questions of step 4 are yes and `game-smoke` shows no new `FAIL` against the
before run. A `FAIL` present in both the before and after runs does not block done for the art task;
this overrides the `Caller:` line of `game-smoke` for that case only. Report that `FAIL` by name.

## Image tools

Use the image tool you have to generate assets. If none is available, the loop still works with
images the user supplies: ask for them, and run the same steps on those.

## 1. Before shots

Run `game-smoke` (pass the platform and the screens to cover). Keep the PNG paths it cites as the
"before" set. Read the `Art direction` line of `design/brief.md` when it exists.

## 2. Fix one reference image

Exactly one image defines the look. Either the user names one, or you pick one existing asset (or
generate one) and show it. Do not average several. Ask the user to confirm it when the choice is
open; do not go on with two candidates.

A white or tinted glyph (the UI kit's icons) is not a reference; use a coloured image or a
screenshot of the intended look, or ask.

If the project has no image for the thing the request names, say so first. Art enters through the
template's skin hooks (README, "Look"): `Resources/Branding/menu-background.png` and
`Resources/GameSkin.json` (`backgrounds.game`, `backgrounds.menu`). A character drawn in code needs
a code change, so ask whether that is wanted.

When no user can answer in this run, stop after this step and report `BLOCKED: need <image or
confirmation>`. Continue with stand-ins only if told to, and name every stand-in in `look.md` and
in the report.

Write `design/look.md`, one screen at most:

- **Reference:** the image's path in the project
- **Palette:** hex values. One pixel of an image as hex:
  `ffmpeg -i <img> -vf crop=1:1:x:y -f rawvideo -pix_fmt rgb24 - | xxd -p`
- **Shape language:** for example rounded and chunky, or angular and thin
- **Line:** weight and colour, or none
- **Light:** direction and softness
- **Perspective:** for example flat side view, top-down
- **Detail level:** how much texture and small shapes
- **Never:** what must not appear (other styles, text in art, a second outline weight)

The template's style family (`theme`: `bright`, `neon`, `pastel`, `bold`, `nature`, `clean`) is
the UI's look. Start from the applied family (`theme.family` in `.cmpose/generation.json`); name
another only when the reference clearly belongs to it. Make the palette in `look.md` agree with the
family. The family is described in "Look: style family, fonts and the UI kit" of the template's
README, and `.cmpose/themes.json`. If none fits, say so in `look.md` instead of bending the art.

## 3. Make assets from the reference and the page

Every new or reworked asset is generated with the reference image attached and the text of
`look.md` in the prompt. Same style and size family as the reference; the canvas is the screen's
aspect for a background and the sprite's own for a character. Check each asset against the reference side by side with a contact image you can
read:

```bash
mkdir -p qa/look
ffmpeg -y -i ref.png -i new.png -filter_complex \
  "[0:v]scale=-2:512[a];[1:v]scale=-2:512[b];[a][b]hstack" qa/look/contact-<asset>.png
```

Both sides are scaled to the same height. Read the PNG and note what differs in palette, line,
light and detail. Fix the asset, not the page, unless the page was wrong; then change the page and
say so. Without `ffmpeg`, `sips` or ImageMagick `convert +append` after resizing does the same.

Put the asset in the game, keeping the file or prefab references that exist. A sprite needs Sprite
import (`textureType: 8` in its `.meta`) and a path under a `Resources` folder when code loads it,
or `Resources.Load<Sprite>` returns null without a message. A test that goes red because of the
asset is a result: report it by name; do not edit the test.

## 4. Play-test

Each round is step 3 then step 4. Run `game-smoke` again for the same screens. Read the new PNGs and judge, at phone size:

- Is the character, or the item the player must find, readable against the background?
- Do the new assets match the reference, in the same frame as the old ones?
- Do touch targets and text stay clear of the art, with enough contrast (at least 4.5:1 for text,
  3:1 for large text)?

Compare the before and after runs check by check, not by the `Verdict` line alone: a `FAIL` verdict
can stay while a new failure hides in it. For tests, compare failing test names. The smoke report
may give only counts, so read the names from `Builds/editmode.xml` and `Builds/playmode.xml` (the
`<test-case>` elements with `result="Failed"`; keep a copy of the before run's, as the after run
overwrites them). A `FAIL` present in both is not caused by the art: say so and name it. A new
`FAIL`, or a new failing test, is caused by it.

Then pick **one change** for what is worst. It is the next round's step 3. Maximum **three rounds**.
After the third, only name the change and report what is left; do not loop "until it looks right".

## Report

- the reference image path and `design/look.md`
- the rounds run and the one change of each
- the before and after device screenshots, by path
- what is left, and anything `game-smoke` marked `NOT RUN` or `NOT ASSESSED`

Only the user can judge how it feels; say so in one line. Do not commit the screenshots or push.

## Out of scope

3D worlds and model or animation pipelines. Gameplay and UI layout changes beyond what the art
needs.
