---
name: game-release
description: Use when a Unity 6 mobile game generated from the cmpose template is about to go to Google Play or the App Store, when asked whether the game is ready to ship, for a store release checklist, or after launch for a post-mortem.
---

# Game release

Checks that a game is ready for the stores by reading its real files and running exact commands,
then writes a verdict. It changes nothing except `qa/release-<date>.md`. The post-mortem is a
separate mode: [post-mortem](references/post-mortem.md).

Every row below is one of two kinds:

- **Checked**: a command or file read in this project. The result is `PASS`, `FAIL` or `NOT RUN`.
- **Needs the owner**: a store console, a real device or legal text. It is `NOT ASSESSED` unless
  the user confirms it in this conversation; then it is `CONFIRMED` and says who confirmed.

Do not mark a row `PASS` from memory, from the README, or because a similar row passed.

## Verdict

First match wins:

1. `NOT READY`: any checked row is `FAIL`.
2. `NOT ASSESSED`: any row is `NOT RUN`, or an owner row is unconfirmed. Name each one.
3. `READY`: every row is `PASS` or `CONFIRMED`.

## 0. Project

The project is the current directory unless the request gives a path. `Assets/` and
`ProjectSettings/` must exist, and the editor version (`ProjectSettings/ProjectVersion.txt`) must
start with `6000.`; otherwise stop with `NOT ASSESSED` and write nothing. Read `git status --short`
and `git rev-parse --short HEAD`; a dirty tree is stated in the report.

## 1. Checked rows

| # | Row | Check | FAIL when |
|---|---|---|---|
| 1 | Smoke report | Newest `qa/smoke-*.md`. Its verdict line and `Visual` line. Its date against `git log -1 --format=%cI -- Assets ProjectSettings` | No report, or older than that commit, or overall verdict not `PASS` / `PASS WITH WARNINGS`, or `Visual` not `DONE` on a platform you ship |
| 2 | Version | `bundleVersion` and `AndroidBundleVersionCode` in `ProjectSettings/ProjectSettings.asset`; the iOS `buildNumber` map in the same file. Ask the user once in this run whether the game was released before | A field is empty; or the game was released before and the version or code is the value of the last release (ask for it) or the template's `1.0.0` with code `1`. No answer to the question: `NOT RUN` |
| 3 | Package and bundle id | `applicationIdentifier` (`Android` and `iPhone` lines) in the same file | An id starting `com.example.`, the template's own id. The two ids differing is a `WARN`, stated in the report |
| 4 | Scripting and ABI | Under `scriptingBackend:` the `Android:` value is `1` (IL2CPP), and `AndroidTargetArchitectures` includes ARM64 (bit `2`) | `Android:` is `0` or the key is missing (Mono), or no ARM64 |
| 5 | Android signing | `keystore.properties` exists, has non-empty `storeFile`, `storePassword`, `keyAlias`, `keyPassword`, and `storeFile` exists; `git check-ignore keystore.properties` prints it. Never print the passwords | Missing file or field: the build falls back to the debug key, which Google Play rejects. File not git-ignored |
| 6 | Android bundle | Build with `-cmposeAab` (see below). The log has `CMPOSE_BUILD_RESULT` with `result=Succeeded` and the `.aab` exists | Build failed or no `.aab` |
| 7 | Test IDs gone: ads | In `Assets/_Project/Core/Ads/AdsConfig.cs` check only the unit-id constants (`Banner*`, `Interstitial*`, `Rewarded*`, form `ca-app-pub-<publisher>/<unit>`) for the publisher `3940256099942544`; ignore `GoogleTestPublisher` and the tests, which hold it on purpose. Separately, in `Assets/GoogleMobileAds/Resources/GoogleMobileAdsSettings.asset` check `adMobAndroidAppId` and `adMobIOSAppId` (form `ca-app-pub-<publisher>~<app>`, with a `~`) for the same publisher | Any such constant or app id carries it. Report which form each file holds. Files absent because the game has no ads flag: `n/a` |
| 8 | Test IDs gone: purchases | `ApiKeyApple` starts `appl_` and `ApiKeyGoogle` starts `goog_` in `Assets/_Project/Core/Purchases/PurchasesConfig.cs`, and `PremiumEntitlement` is set | A key that does not start so (the template ships RevenueCat's Test Store key, and release builds keep purchases off). No purchases flag: `n/a` |
| 9 | Release log lines | The running game prints `CMPOSE_ADS available=true` (no "test IDs" warning), `CMPOSE_PURCHASES available=true` and `CMPOSE_INSIGHTS available=true`; the batch build does not. Look for a saved device log of a release build under `qa/` or `Builds/logs` (grep the markers), no older than the last commit touching `Assets/` or `ProjectSettings/` (`git log -1 --format=%cI -- Assets ProjectSettings`). `game-smoke` keeps only Unity and build logs and PNGs, so such a log exists only when someone saved one, for example `adb -s <serial> logcat -d -s Unity` | A fresh log shows `available=false` or the warning. No such log: `NOT RUN`, never `PASS`; say that the owner confirms them on a real device |
| 10 | Privacy manifest | `Assets/Plugins/iOS/PrivacyInfo.xcprivacy` exists and parses: `plutil -lint <file>` | Missing or does not parse |
| 11 | Firebase files | With the insights flag: `Assets/Firebase/google-services.json` and `Assets/Firebase/GoogleService-Info.plist` exist, and their package name and bundle id match row 3 | Missing or mismatching. No insights flag: `n/a` |
| 12 | Build size | Size of the `.aab` from row 6 (`ls -l`) | Over the budget the owner names. No budget given: the size is stated and is not a failure |
| 13 | Uncommitted work | `git status --short` | Not a FAIL; state it, because the smoke report (row 1) compares against commits |

### Android bundle command

`<ns>` is the full namespace after `namespace` in `Assets/Editor/Build/BuildScript.cs`, ending in
`.Editor.Build`. Never when `Temp/UnityLockfile` exists (the editor has the project open): row 6 is
then `NOT RUN`. Run in the background and wait; it can take ten minutes.

```bash
mkdir -p Builds/logs
"$UNITY" -batchmode -nographics -quit -projectPath "$PWD" -buildTarget Android -executeMethod <ns>.BuildScript.BuildAndroid -cmposeOut "$PWD/Builds/game.aab" -cmposeAab -logFile Builds/logs/release-android.log
grep CMPOSE_BUILD_RESULT Builds/logs/release-android.log
```

`$UNITY` is `$UNITY_EDITOR`, else `/Applications/Unity/Hub/Editor/<version>/Unity.app/Contents/MacOS/Unity`, with `<version>` read from `m_EditorVersion` in `ProjectSettings/ProjectVersion.txt`.
Without `keystore.properties` this still builds, signed with the debug key; row 5 is the failure.

### iOS

No command here builds the signed archive. iOS rows are owner rows (below) unless the user gives
you an archive to inspect. `Builds/ios` from `game-smoke` is a simulator build and says nothing
about signing.

## 2. Owner rows

List each with what the owner must do. Unconfirmed means `NOT ASSESSED`.

| Row | What the owner confirms |
|---|---|
| Xcode archive | Opened `Builds/ios/Unity-iPhone.xcodeproj`, chose the team under Signing & Capabilities, archived and validated the archive |
| Google Play Data safety | Form filled to match what the game collects (with insights: crash logs, diagnostics, app interactions, device ids; with ads and purchases, their SDKs' lists) |
| App Store privacy answers | App Privacy answers filled; with ads, the App Tracking Transparency text and the IDFA explainer in AdMob |
| Consent message | With ads: the AdMob consent message (Privacy & messaging) published |
| Account deletion | Only when the game has accounts or sign-in: the deletion path inside the app and the Play Console deletion URL |
| Privacy policy | Published, linked in both stores and from inside the game |
| Age rating | Questionnaires answered in both consoles |
| Store images and listing | App icon (not Unity's default), title, description, screenshots and the Play feature graphic; screenshots for the sizes App Store Connect asks for |
| Store products | With purchases: products, the `premium` entitlement and the `shop` offering set up in RevenueCat and in both stores |
| Real device | The release build installed and played on at least one real Android phone and one real iPhone, not only emulators |
| Native symbols | With insights: Android symbols uploaded (`firebase crashlytics:symbols:upload`), as the template README describes |

## 3. Store checkers

When `app-store-rejection-checker` or `play-store-rejection-checker` is installed (look under
`~/.claude/skills/` and `.claude/skills/`), end the report with a line telling the user to run it
as the last step. Do not run it here, and do not depend on it: when it is absent, say nothing about
it.

## 4. Report

Write `qa/release-<date>.md` (`date +%F`, with `-2` appended when the file exists). Do not commit it.

```markdown
# Release check <date>

Project: <name> | Unity <version> | Commit <short sha, "+ uncommitted" if dirty>

| # | Row | Result | Evidence |
|---|---|---|---|
| 1 | Smoke report | FAIL | qa/smoke-2026-11-01.md is older than the last commit touching Assets/ |
| 5 | Android signing | PASS | keystore.properties complete, git-ignored |

## Owner rows
| Row | Status |
|---|---|
| Xcode archive | NOT ASSESSED |

Verdict: NOT READY
Blockers: <each FAIL, one line, with the fix>
Not assessed: <each NOT RUN or unconfirmed owner row>
```

Final message to the caller: the verdict, the blockers and the not-assessed list, the report path,
and the checker line from section 3 when it applies. A stale or missing smoke report is named as the
blocker; do not re-run `game-smoke` from here, tell the user to run it.

## Never

Edit the project, change signing or keys, commit, upload to a store, or mark an owner row done on
the user's behalf without them saying so.
