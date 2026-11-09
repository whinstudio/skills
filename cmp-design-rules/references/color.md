# Colour ramps and contrast

## Build a ramp

OKLCH has even perceived lightness, so a ramp built in it has even steps. Mixing hex values does not.
No web tool is needed: Compose has Oklab built in, and OKLCH is Oklab in polar form.

1. Pick the hue `h` (0 to 360) from the read in `SKILL.md`, section 1, and a peak chroma `C`, usually 0.12 to 0.20.
2. Take `L` from this table, which is a starting point. The accent's hue never moves, and its chroma
   rises to the peak at 500 to 600 and falls again.

| Step | L | Neutral chroma | Accent chroma |
|---|---|---|---|
| 50 | 0.97 | 0.005 | 0.15 × C |
| 100 | 0.93 | 0.006 | 0.30 × C |
| 200 | 0.87 | 0.008 | 0.50 × C |
| 300 | 0.79 | 0.010 | 0.70 × C |
| 400 | 0.70 | 0.012 | 0.90 × C |
| 500 | 0.62 | 0.014 | C |
| 600 | 0.54 | 0.014 | C |
| 700 | 0.46 | 0.012 | 0.90 × C |
| 800 | 0.37 | 0.010 | 0.70 × C |
| 900 | 0.28 | 0.008 | 0.50 × C |
| 950 | 0.20 | 0.006 | 0.35 × C |

Use the accent's hue for the neutrals too, so they read as one family. Chroma near 0 is a plain grey.

3. Convert each step in a throwaway test in `core/designsystem/src/commonTest`, run it with
   `./gradlew :core:designsystem:allTests --info`, copy the hex values into the palettes, and delete the test.

```kotlin
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.colorspace.ColorSpaces
import androidx.compose.ui.graphics.toArgb
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

private fun oklch(l: Float, c: Float, hueDegrees: Float): Color {
    val h = hueDegrees * PI.toFloat() / 180f
    return Color(l, c * cos(h), c * sin(h), colorSpace = ColorSpaces.Oklab).convert(ColorSpaces.Srgb)
}

// oklch(0.54f, 0.16f, 45f).toArgb().toUInt().toString(16) gives the 0xAARRGGBB value
```

A channel that lands on `00` or `ff` means the colour is outside sRGB and the hue will drift: lower the
chroma for that step.

The two values used most are the accent's 500 to 600 step (buttons) and the neutral's 50 to 100 step
(backgrounds). In dark mode the neutral's 900 to 950 is the background, higher surfaces move toward 800,
and the accent moves to about 300 to 400. Check every result in the next section.

## Check a pair

1. Composite first. A colour with alpha has no contrast of its own: `textGray` in the dark palette is
   `0x80FFFFFF`, which is 50% white on whatever is behind it. `Color.luminance()` ignores alpha.
2. Compute the luminance of each colour, then the ratio.

By hand or in any language, per channel `c` from 0 to 1:

```
linear = c / 12.92                      if c <= 0.04045
linear = ((c + 0.055) / 1.055) ^ 2.4    otherwise
Y      = 0.2126 R + 0.7152 G + 0.0722 B
ratio  = (Ylighter + 0.05) / (Ydarker + 0.05)
```

Composite each channel: `result = alpha × foreground + (1 − alpha) × background`.

In a project, add a test beside `ColorSchemeForTest` and keep it, so a later colour change cannot break
contrast unnoticed:

```kotlin
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.luminance
import kotlin.math.max
import kotlin.math.min
import kotlin.test.Test
import kotlin.test.assertTrue

class PaletteContrastTest {

    private fun contrast(foreground: Color, background: Color): Float {
        val fg = foreground.compositeOver(background).luminance()
        val bg = background.luminance()
        return (max(fg, bg) + 0.05f) / (min(fg, bg) + 0.05f)
    }

    @Test
    fun mutedTextIsReadableInBothModes() {
        listOf(OnLightColorsPalette, OnDarkColorsPalette).forEach { palette ->
            val ratio = contrast(palette.textGray, palette.backgroundColor)
            assertTrue(ratio >= 4.5f, "textGray on backgroundColor is $ratio")
        }
    }
}
```

Add one assertion per pair the screens use. On the template as generated this test fails for the light
palette (3.05:1) until `textGray` is darkened. Text on a filled accent is the pair most often missed:
`onPrimary` on `primary`.
