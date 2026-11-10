# Review how the app looks

Section numbers refer to `SKILL.md`. Do not change code in this pass. Report, then fix what is asked.

1. Read `theme/`, then list the screens: every screen composable under `feature/*/presentation`, wherever
   its package is (not only `ui/`), and `shared/`.
2. From the project root, run each pattern with
   `grep -rnE --include='*.kt' --exclude-dir=build '<pattern>' feature shared core/designsystem`,
   and ignore hits in `theme/`, `icon/`, imports and tests. In a blank app skip the `KtText` and `Text`
   patterns.
   - `Color\((0x|color =)|Color\.(White|Black|Red|Gray)`: raw colour, no dark value.
   - `[0-9]\.sp\b`: type size outside the scale.
   - `\bKtText\(`: read each; `style =` without `fontWeight = null` loses the style's weight.
   - `\bText\(`: bypasses `KtText`.
   - `RoundedCornerShape\(`: shape outside the theme. `CircleShape` is fine.
   - `(text|label|title|contentDescription|placeholder|placeHolderText) = "[^"]|\bText\("`: hard-coded
     text. A value with no words to translate (`"@${user.login}"`) is not.
   - `\.clickable`: read each with its `size` and `padding`; a target under 48 dp. Mark a height you
     worked out from the code as estimated.
   - `indication = null`: no pressed state.
   - `animate|AnimatedContent|AnimatedVisibility|Crossfade|InfiniteTransition`: check against section 7.
     A bare `when` that swaps loading, error and content is also a finding.
   - `delay\(`: read each; only motion counts, a search debounce does not.
3. Contrast, in both palettes, with the ratio written in the finding:
   - every text and background pair the screens use;
   - icons and input edges against their background, at 3:1 (`outline` included);
   - focused against unfocused: the two borders must differ, and the focused one reaches 3:1.
4. States: every screen that loads has loading, empty, error and content. The error text follows the
   error type where the state holds a `DataError`. The empty state has a next action.
5. Per screen: count accent uses, type sizes and nested cards; look for stock lilac from an unmapped
   role (section 2). A palette read for a role Material has is not a finding in existing code.
6. If you can run the app, screenshot each screen in light and dark and add what the code does not show.
   If you cannot, write `Not seen on a device` under the findings.

End with this list, most severe first. A cause in the theme is one finding at its theme line, not one per
call site. Any other cause is one row per file. In a headless run, put `Assumptions` above the table.

```
| # | Severity | Location | Rule | Finding | Fix |
|---|---|---|---|---|---|
| 1 | High | core/designsystem/.../theme/CustomColorsPalette.kt:32 | Contrast | textSecondary #8B959E on #FFFFFF is 3.05:1, needs 4.5:1 | Darken to pass; #6B7580 is 4.69:1 |
```

| Severity | Means |
|---|---|
| High | Fails a number or loses information: contrast under the minimum, target under 48 dp, hard-coded text, a raw colour with no dark value, a missing state, an error shown as empty |
| Medium | Breaks the system: raw type, shape or spacing where a token exists, a stock role showing, motion against section 7 |
| Low | Polish: hierarchy, rhythm, copy tone |
