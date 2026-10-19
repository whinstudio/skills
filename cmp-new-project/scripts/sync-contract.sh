#!/usr/bin/env bash
# Regenerate the skill's contract from @cmpose/core (the generator the cmpose MCP runs), so the
# documented validation rules can never silently drift.
#
# Usage:
#   sync-contract.sh            # (re)generate reference/contract.json + reference/payload.md
#   sync-contract.sh --check    # verify the committed contract is current
#
# Core source (first match wins):
#   CMP_CORE_DIR=<dir>          a local packages/core checkout (an unreleased core)
#   CMP_CORE_VERSION=<x.y.z>    that version from npm
#   (neither)                   the version reference/contract.json pins (mcp.version)
# Requires Node 20+ and npm.
#
# Exit codes: 0 = ok / written; 1 = --check found drift; 2 = configuration error
# (node/npm missing, no core version, core not installable).
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"   # skill root (parent of scripts/)
MODE="generate"
[ "${1:-}" = "--check" ] && MODE="check"

command -v node >/dev/null 2>&1 || { echo "ERROR: node is required for sync-contract.sh"; exit 2; }

CORE_DIR="${CMP_CORE_DIR:-}"
if [ -z "$CORE_DIR" ]; then
  command -v npm >/dev/null 2>&1 || { echo "ERROR: npm is required for sync-contract.sh"; exit 2; }
  VER="${CMP_CORE_VERSION:-}"
  if [ -z "$VER" ] && [ -f "$HERE/reference/contract.json" ]; then
    VER="$(node -e 'try { process.stdout.write(require(process.argv[1]).mcp.version || "") } catch (e) {}' "$HERE/reference/contract.json")"
  fi
  [ -n "$VER" ] || { echo "ERROR: set CMP_CORE_VERSION (e.g. 0.3.0) or CMP_CORE_DIR"; exit 2; }
  TMP_CORE="$(mktemp -d)"
  trap 'rm -rf "$TMP_CORE"' EXIT
  npm install --prefix "$TMP_CORE" --no-save --no-audit --no-fund --loglevel=error "@cmpose/core@$VER" >/dev/null \
    || { echo "ERROR: npm could not install @cmpose/core@$VER"; exit 2; }
  CORE_DIR="$TMP_CORE/node_modules/@cmpose/core"
fi
[ -f "$CORE_DIR/package.json" ] || { echo "ERROR: @cmpose/core not found at $CORE_DIR"; exit 2; }

SKILL_DIR="$HERE" CORE_DIR="$CORE_DIR" MODE="$MODE" node <<'NODE'
'use strict';
const fs = require('fs');
const path = require('path');

const SKILL_DIR = process.env.SKILL_DIR;
const CORE_DIR = process.env.CORE_DIR;
const MODE = process.env.MODE;

const contractPath = path.join(SKILL_DIR, 'reference', 'contract.json');
const payloadPath  = path.join(SKILL_DIR, 'reference', 'payload.md');

const warnings = [];

// The generator's own contract: @cmpose/core computes the facts and the version; never the skill.
let core;
try {
  core = require(CORE_DIR);
  if (typeof core.contractFacts !== 'function' || typeof core.hashContract !== 'function') throw new Error('contractFacts/hashContract not exported');
} catch (e) {
  console.error('ERROR: cannot load @cmpose/core from ' + CORE_DIR + ': ' + e.message);
  process.exit(2);
}

// --- Hand-maintained maps (not part of the generator's contract)
// TR + EN intent keywords → featuresConfig flag. Lowercase substring match.
const keywordMap = {
  network:          ['network', 'ktor', 'networking', 'api client', 'http', 'ağ', 'istek'],
  networkInspector: ['network inspector', 'inspector', 'chucker', 'http inspector', 'network monitor', 'ağ izleyici'],
  theming:          ['theming', 'theme', 'dark mode', 'light mode', 'material', 'tema', 'karanlık mod', 'koyu tema'],
  multiLang:        ['multi-language', 'multilanguage', 'multi language', 'i18n', 'l10n', 'localization', 'localisation', 'çoklu dil', 'yerelleştirme', 'dil desteği'],
  dataStore:        ['datastore', 'data store', 'preferences', 'persistence', 'local storage', 'yerel depolama', 'saklama'],
  // room: a local database / offline storage of structured data (DataStore is for preferences).
  // 'database' and 'veritabanı' both map here (TR/EN symmetric); no bare 'db' (substring of e.g. 'dbus', 'mongodb').
  room:             ['room database', 'sqlite', 'local database', 'offline storage', 'offline database', 'database', 'veritabanı', 'yerel veritabanı', 'çevrimdışı depolama'],
  detekt:           ['detekt', 'static analysis', 'lint', 'kod analizi', 'statik analiz'],
  // purchases/ads: explicit monetization intent ONLY. Naming a featuresConfig key switches the
  // template to blank, so ordinary app descriptions must not match: no 'premium', 'subscription',
  // 'purchases', 'satın alma', 'abonelik', 'monetization' (a "subscription tracker" or "an app that
  // tracks purchases" is not a paywall request). No bare 'ads' / 'advert' / 'reklam' either:
  // substrings of 'downloads', 'threads', 'advertise', 'reklamasyon'.
  purchases:        ['revenuecat', 'in-app purchase', 'in app purchase', 'paywall', 'uygulama içi satın alma', 'abonelik ekranı'],
  ads:              ['admob', 'banner ad', 'interstitial', 'rewarded ad', 'reklam göster', 'reklam ekle'],
  // backend: explicit intent ONLY, as for purchases (naming it switches the template to blank). The skill turns it on
  // when the request asks for a server, sign-in or sharing between users, not for an app that merely shows accounts.
  backend:          ['backend', 'server', 'sunucu', 'sign in', 'giriş yap', 'login', 'hesap', 'account', 'paylaş', 'share with']
};
// Words that mean "give me the full example app".
const templateKeywords = {
  showcase: ['showcase', 'example app', 'full example', 'sample app', 'demo app', 'örnek uygulama', 'örnek proje', 'her şey', 'hepsi', 'dolu']
};
// Top-level options (not featuresConfig: naming them does not switch the template to blank).
// No bare 'ci': a substring of 'decision', 'special', 'efficient'.
const projectOptionKeywords = {
  ci: ['github actions', 'continuous integration', 'ci pipeline', 'ci/cd', 'ci workflow', 'sürekli entegrasyon']
};
// --- Assemble the contract (everything except the volatile _generated block) -
function buildContract() {
  const f = core.contractFacts();
  return {
    contractVersion: core.hashContract(f),
    // @cmpose/core and @cmpose/mcp are released together with the same version
    mcp: {
      package: '@cmpose/mcp',
      version: core.version,
      install: `claude mcp add cmpose -- npx -y @cmpose/mcp@${core.version}`
    },
    // STATIC fallback values. At runtime the skill prefers cmp_describe's contract.limits.
    limits: {
      minSdkMin: f.limits.minSdkMin,
      minSdkMax: f.limits.minSdkMax,
      iosVersionMin: f.limits.iosVersionMin,
      iosVersionMax: f.limits.iosVersionMax,
      maxModules: f.limits.maxModules,
      sdkNote: 'targetSdk and compileSdk come from the template (build-logic/src/main/kotlin/config/AppConfig.kt of the generated project)'
    },
    maxLengths: f.maxLengths,
    regex: f.regex,
    kotlinHardKeywords: f.kotlinHardKeywords,
    reservedModuleNames: f.reservedModuleNames,
    reservedPackagePrefix: f.reservedPackagePrefix,
    messages: f.messages,
    templateTypes: f.templateTypes,
    featuresConfigKeys: f.featuresConfigKeys,
    dependencyRules: f.dependencyRules,
    projectOptions: f.projectOptions,
    projectOptionKeywords,
    keywordMap,
    templateKeywords,
    anatomy: f.anatomy
  };
}

// --- Render the human-readable mirror ---------------------------------------
function renderPayloadMd(c, gen) {
  const L = c.limits, X = c.maxLengths, R = c.regex;
  return `<!-- GENERATED by scripts/sync-contract.sh on ${gen.date} from @cmpose/core ${c.mcp.version}.
     Do not hand-edit — run \`scripts/sync-contract.sh\` to refresh. -->

# \`cmp_generate\` arguments

Mirrors the cmpose generator's contract (\`@cmpose/core\` ${c.mcp.version}, served by the local cmpose MCP
server). **At runtime, always prefer \`cmp_describe\`'s \`contract.limits\` over the static numbers below.**

## Tools
- MCP server: \`${c.mcp.install}\` (Node.js 20+ and git; restart Claude Code after adding it).
- \`cmp_describe\` (no arguments) → \`{ contractVersion, coreVersion, mcpVersion, template: { repo, ref }, defaults, contract }\`.
- \`cmp_generate\` → writes \`<outputDir>/<projectName>\` on this machine and returns \`structuredContent\`
  \`{ projectDir, template: { repo, ref, commit }, templateType, features, featuresConfig, warnings, nextSteps }\`.
  - A refused request returns an error result (\`isError\`) whose text is the reason: one of the validation
    messages below, \`<dir> already exists and is not empty\`, \`Unknown featuresConfig key(s): …\`, or a template
    download error (the first run downloads the pinned template).
  - It never overwrites a non-empty folder and never leaves half a project behind.

## Body
\`\`\`jsonc
{
  "outputDir": "/absolute/parent/folder", // absolute; the project goes to <outputDir>/<projectName>
  "projectName": "MyApp",            // ${R.projectName}  · ≤${X.projectName} · no spaces
  "appName": "My App",               // letters/digits/space . _ ' - · trimmed · ≤${X.appName}
  "packageName": "com.example.myapp", // ${R.packageName} · ≤${X.packageName} · ≥3 segments · no Kotlin keyword segments · not ${c.reservedPackagePrefix} or under it
  "minSdk": "${L.minSdkMin}",                    // numeric string (1–${X.minSdk} digits) in [${L.minSdkMin}..${L.minSdkMax}]
  "iosVersion": "${L.iosVersionMin}",              // ${R.iosVersionFormat} in [${L.iosVersionMin}..${L.iosVersionMax}]
  "templateType": "blank",           // "blank" | "showcase"
  "ci": false,                       // GitHub Actions CI (.github/workflows/ci.yml: pull requests + manual runs); every template; default false
  "featuresConfig": {                // used only for "blank"; ignored for "showcase"
    "network": true,
    "networkInspector": true,        // requires network=true
    "networkBaseUrl": "",            // optional; http(s) URL if non-empty · no whitespace, " \\ $ · ≤${X.networkBaseUrl}
    "theming": true,
    "multiLang": true,
    "dataStore": true,               // auto-true if theming || multiLang
    "detekt": true,
    "detektYamlContent": null,       // optional custom detekt.yml as a string
    "purchases": true,               // custom paywall on RevenueCat; ships a Test Store key — replace it before you ship
    "ads": true,                     // AdMob banner/interstitial/rewarded (Google test IDs) + UMP/ATT consent
    "room": false,                   // Room KMP database (core/room) + a Notes demo; only for a local database / offline storage, not preferences
    "backend": false                 // Ktor server (server/) + Firebase sign-in + spaces/sharing; implies multiLang + network
  },
  "features": ["profile"]            // custom modules · each ${R.moduleName} · ≤${X.moduleName} · count ≤ maxModules (${L.maxModules})
}
\`\`\`

## Validation rules (mirror for fast feedback; cmp_generate's error is authoritative)
| Field | Rule | Max len |
|---|---|---|
| projectName | \`${R.projectName}\`, no spaces | ${X.projectName} |
| appName | non-empty, no leading/trailing space; only letters (any script, incl. combining marks), digits, space and \`. _ ' -\` | ${X.appName} |
| packageName | \`${R.packageName}\` (≥3 segments); no segment may be a Kotlin hard keyword (\`kotlinHardKeywords\`); must not equal or sit under the reserved template package \`${c.reservedPackagePrefix}\` (\`reservedPackagePrefix\`) | ${X.packageName} |
| module name | \`${R.moduleName}\`; not a Kotlin hard keyword; not a reserved name (${c.reservedModuleNames.map(n => '\`' + n + '\`').join(', ')}) | ${X.moduleName} |
| module count | ≤ \`maxModules\` (${L.maxModules}) | — |
| minSdk | numeric string of 1–${X.minSdk} digits, in [${L.minSdkMin}..${L.minSdkMax}] | ${X.minSdk} |
| iosVersion | \`${R.iosVersionFormat}\` within [${L.iosVersionMin}..${L.iosVersionMax}] | ${X.iosVersion} |
| networkBaseUrl | \`http://\` or \`https://\` only; no whitespace, \`"\`, \`\\\`, \`$\`; checked only for blank + \`network: true\` + non-empty | ${X.networkBaseUrl} |

Kotlin hard keywords (\`kotlinHardKeywords\`): ${c.kotlinHardKeywords.map(k => '\`' + k + '\`').join(', ')}.

## Always-on (not configurable, not in the payload)
- **Dependency Injection (Koin)** and **Navigation** are always included.

## Feature dependencies (enforce BEFORE sending)
- \`networkInspector: true\` ⇒ set \`network: true\`.
- \`theming: true\` or \`multiLang: true\` ⇒ set \`dataStore: true\`.
- \`purchases\` and \`ads\` are independent. With both on, an active premium entitlement hides the ads.
- \`backend → multiLang, network\`: \`backend: true\` ⇒ set \`multiLang: true\` and \`network: true\` (and so \`dataStore: true\`).

## Monetization (\`purchases\`, \`ads\`)
- \`purchases\` → \`core/purchases\` (RevenueCat KMP behind \`PurchasesManager\`: \`offer()\`, \`purchase(packageId)\`, \`restore()\`) + a custom Compose paywall and \`FirstLaunchPaywall()\` in \`feature/monetization\`.
  The project ships with a RevenueCat **Test Store** API key: replace it with your own platform keys
  before you ship to a store. A **release** build that still has the Test Store key keeps purchases
  disabled (the paywall shows a message instead of offerings).
- \`ads\` → \`core/ads\` (AdMob banner, interstitial and rewarded, with Google's test ad unit IDs) +
  an ads demo screen in \`feature/monetization\`. UMP consent (and ATT on iOS) is requested on the
  first visit to the ads screen, not at app launch; a real app should ask at launch. The EEA consent
  debug geography is applied in debug builds only.
- Either flag adds \`feature/monetization\`; \`monetization\` is therefore a reserved module name.

## Room (\`room\`)
- \`room\` → \`core/room\` (Room KMP with bundled SQLite: \`AppDatabase\`, DAOs, exported \`schemas/\`) and, in
  blank, a Notes demo screen in \`feature/notes\`. Showcase always has \`core/room\` (it stores the
  favorites) and never \`feature/notes\`. \`notes\` is therefore a reserved module name.
- Turn it on only when the user asks for a local database or offline storage of structured data.
  Preferences and settings belong in DataStore (\`dataStore\`). \`room\` is independent: it implies nothing.
- Notes is a demo: replace it or remove it. New tables go into the existing \`AppDatabase\`.

## Backend (\`backend\`)
- \`backend\` → a Ktor server in \`server/\` (Firebase ID-token check, Flyway migrations with \`V1\` = users, spaces,
  members, invites, files; tests on an embedded PostgreSQL), \`core/api\` (models and routes shared by the app and the
  server), \`core/auth\` (Firebase sign-in: email, Google, Apple; the backend client's token), \`feature/account\`
  (sign-in, settings, account deletion) and \`feature/sharing\` (spaces, members, invites).
- Blank only: showcase ignores \`featuresConfig\` and never contains the server parts.
- Turn it on only when the user explicitly asks for a server/backend, sign-in, or sharing data with other users.
- Invite link: \`<scheme>://invite/<token>\`. \`account\` and \`sharing\` are therefore reserved module names.
- After generation: add your own Firebase config files (\`google-services.json\`, \`GoogleService-Info.plist\`; never
  commit them), then start the local server with \`./gradlew :server:runLocal\` (an embedded PostgreSQL kept in
  \`.local-server/\`; \`:server:resetLocal\` deletes it). App data is added with the \`cmp-backend\` skill.

## blank vs showcase
- **blank**: \`featuresConfig\` reflects the user's choices; \`features\` = custom modules
  (each name once; a duplicate is refused).
- **showcase**: send \`templateType:"showcase"\` and put any requested custom modules in
  \`features\` (\`features: []\` when none). The generator keeps the default \`home\` +
  \`onboarding\` modules and **ignores \`featuresConfig\`** (it strips any
  \`home\`/\`onboarding\` you put in \`features\`). Custom modules are added next to them,
  fully wired (their screens are registered; the showcase still opens on onboarding).

## Generator error messages (match these exactly when re-asking)
${Object.entries(c.messages).map(([k, v]) => `- \`${k}\`: ${v}`).join('\n')}

## Anatomy (which modules appear)
- Always: ${c.anatomy.always.join(', ')} — ${c.anatomy.alwaysNote}
${Object.entries(c.anatomy.coreModules).map(([m, r]) => `- \`${m}\`: ${r.requires ? 'if ' + r.requires.join(' && ') : 'if ' + r.requiresAny.join(' || ')} (${r.note})`).join('\n')}
${Object.entries(c.anatomy.featureModules || {}).map(([m, r]) => `- \`${m}\`: ${r.requires ? 'if ' + r.requires.join(' && ') : 'if ' + r.requiresAny.join(' || ')} (${r.note})`).join('\n')}
- \`${c.anatomy.detektDir.path}\`: if ${c.anatomy.detektDir.requires.join(' && ')}
- showcase adds: ${c.anatomy.showcaseFeatures.join(', ')}
- each custom module → \`${c.anatomy.customFeaturePath}\` with layers: ${c.anatomy.customFeatureLayers.join(', ')}
`;
}

// --- Run ---------------------------------------------------------------------
let fresh;
try { fresh = buildContract(); } catch (e) {
  console.error('ERROR: contractFacts()/contractVersion() failed: ' + e.message);
  process.exit(2);
}
warnings.forEach(w => console.error('  WARN: ' + w));

if (MODE === 'check') {
  if (!fs.existsSync(contractPath)) { console.error('DRIFT: reference/contract.json is missing — run sync-contract.sh'); process.exit(1); }
  const existing = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
  delete existing._generated;
  if (JSON.stringify(fresh) !== JSON.stringify(existing)) {
    console.error('DRIFT: reference/contract.json is out of sync with @cmpose/core. Run scripts/sync-contract.sh to refresh.');
    // Best-effort field-level hint
    for (const k of Object.keys(fresh)) {
      if (JSON.stringify(fresh[k]) !== JSON.stringify(existing[k])) console.error(`  changed: ${k}`);
    }
    process.exit(1);
  }
  console.log('OK: contract.json is in sync with @cmpose/core' + (warnings.length ? ` (warnings: ${warnings.length})` : ''));
  process.exit(0);
}

// generate mode (no local path recorded: the public repo names only the npm version)
const gen = {
  by: 'scripts/sync-contract.sh',
  date: new Date().toISOString().slice(0, 10)
};
const out = Object.assign({ _generated: gen }, fresh);
fs.mkdirSync(path.dirname(contractPath), { recursive: true });
fs.writeFileSync(contractPath, JSON.stringify(out, null, 2) + '\n');
fs.writeFileSync(payloadPath, renderPayloadMd(fresh, gen));
console.log(`Wrote ${path.relative(SKILL_DIR, contractPath)} and ${path.relative(SKILL_DIR, payloadPath)}.`);
NODE
