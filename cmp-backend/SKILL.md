---
name: cmp-backend
description: Use when adding the app's own data to the server in a project that has a `server/` module (generated with backend) — a new record type stored per space in its own `server/.../feature/<name>/` package (Flyway migration, Exposed table, DTOs, repository, `/api/v1` routes with requireUser and requireRole, its OpenAPI entries), its IDOR and validation tests, the core/api model that ApiContractTest checks, the client repository on the backend client, and the ViewModel, screen and Maestro step that show it. Not for projects without `server/`.
argument-hint: "<entity and its fields>"
---

# Adding app data to the backend

Only for projects that have `server/` next to `core/api`, `core/auth`, `feature/account` and `feature/sharing`.
Without `server/` the project has no backend and this skill does not apply.

`server/` is the cmpose backend template's Ktor server (JVM), generated into the project with sharing on, as an
included Gradle build. Its own `server/README.md` (layout, API conventions) and `server/SECURITY-CHECKLIST.md`
(what every route needs) are the source of truth on the server side; this skill follows them. Read the checklist
before writing and go through it again when you are done.

All data belongs to a **space**. Every user has a personal space (created on their first signed-in request); with
sharing on they can create more and invite others as EDITOR or VIEWER. Roles order VIEWER < EDITOR < OWNER: a
viewer reads, an editor adds, changes and deletes records and files, the owner also manages members and invites.

`<package>` below is the project's package (for example `com.example.trips`); paths are relative to the project root.
The server's code is in the package `<package>.server`: `server/src/main/kotlin/<package as folders>/server/`,
written `server/.../` below (tests: `server/src/test/kotlin/<package as folders>/server/`). For the client layers
follow `cmp-feature` and `cmp-code-rules` as for any feature; this skill adds what is specific to the backend.

## Never touch

- `core/auth`, `feature/account`, `feature/sharing` (screens, repositories, `SelectedSpace`), apart from the one
  `SharingConfig.ENABLED` line below.
- The template's migrations in `server/src/main/resources/db/migration` (`V1__core.sql`, `V2__sharing.sql`, …):
  never edit, rename or renumber them. Flyway checks their checksums, so a changed one fails every existing
  database. Their numbers have gaps on purpose; leave them.
- `server/.../auth` (`requireUser`, the token check), `server/.../sharing` (`requireRole`, `Role`, `Membership`,
  `SpaceRepository`, the space, member and invite routes), `server/.../users` (`/api/v1/me`, account deletion),
  `server/.../files`, `server/.../plugins` (errors, security headers, CORS, body and rate limits, client version)
  and the routes already registered in `Application.kt`. Copy their shape; add next to them.
- `server/src/local` (the local runner), `localServerDir=../.local-server` in `server/gradle.properties` and
  `server/deploy/`: `./gradlew :server:runLocal` from the project root, with the root
  `.local-server/config.properties`, must keep working.
- `BACKEND_CLIENT`, `buildBackendClient` and `BackendConfig` in `core/network`: the backend client is a separate,
  named `HttpClient`; the app's unnamed one stays for other APIs.

## Sharing on or off

`feature/sharing/contract/.../SharingDestinations.kt` has `object SharingConfig { const val ENABLED = true }`.
If the app does not share data between users, set it to `false`: the space switcher and the Share button are
hidden and every record lives in the user's personal space. The server, its routes and checks stay exactly as
below; the personal space is still a space.

## Quotas and invites

The server caps new writes; the limits come from the environment (`server/deploy/.env.example`):
`MAX_STORAGE_BYTES_PER_USER` (default 100 MB; a file counts against its space's owner, also when an editor uploaded
it), `MAX_SPACES_PER_USER` (20, the spaces a user owns besides the personal one), `MAX_MEMBERS_PER_SPACE` (50, owner
included, checked when an invite is accepted) and `MAX_PENDING_INVITES_PER_SPACE` (20, a space's valid invites). `0`
turns one off; lowering one deletes nothing, it only refuses new writes. A refused write answers 409
`QUOTA_EXCEEDED` with `quota` = `storage` | `spaces` | `members` | `invites`; the limit itself is not sent.

- A new record type's image goes through `POST /api/v1/files`, so its upload can be refused with `QUOTA_EXCEEDED`
  (`storage`); the app shows that as full storage (step 9), not as a failure.
- A write you add that a quota counts checks it as `server/SECURITY-CHECKLIST.md` says: in the same locked
  transaction as the write, failing with `quotaExceeded(...)`.

The invite routes are the template's (`server/.../sharing`); the app calls them and never re-implements them. An
OWNER lists a space's valid invites with `GET /api/v1/spaces/{id}/invites` (newest first, at most 200, not paged;
`id`, `role`, `createdAt`, `expiresAt`, never the token) and revokes one with
`DELETE /api/v1/spaces/{id}/invites/{inviteId}` (204, also when called again; 409 `INVITE_USED` once it was used;
another space's invite or an unknown id is 404). Creating an invite answers with its `id` too, the one the DELETE
takes. Accepting a revoked invite answers 410 `INVITE_REVOKED`, and its preview's state is `revoked`.

## The pattern

This project has no sample feature. Copy the shape of `server/.../files/`: `FileRepository.kt` (the Exposed table
object `StoredFiles` and a repository whose methods are each one `transaction(db) { ... }`), `FileRoutes.kt`
(`requireUser()` first, then `requireRole`; a record looked up by id is loaded first and checked in its own space,
`requireFile`) and the tests, `server/src/test/kotlin/<package as folders>/server/FileRoutesTest.kt` (next to the
other tests, not under `files/`). The role checks are in `server/.../sharing/Access.kt`. Read them before writing.

A new record type gets its own package, `server/.../feature/<name>/`, one file per part:

| File | What |
|------|------|
| `<Entity>Dto.kt` | the response, draft and patch DTOs and the validation |
| `<Entity>Repository.kt` | the Exposed table object, then the queries |
| `<Entity>Routes.kt` | `fun Route.<entity>Routes(...)` |
| `<Entity>OpenApi.kt` | its paths and schemas in the API description |

Its tests go in `server/src/test/kotlin/<package as folders>/server/feature/<name>/`.

No file of its own for the table object: a file whose only top-level declaration is `object Trips` must be named
`Trips.kt`, or the server's detekt (`MatchingDeclarationName`, active in `server/detekt.yml`; `:server:build` runs
it) fails, and a `@Suppress` is not allowed. Put the object at the top of `<Entity>Repository.kt`, as `StoredFiles`
sits in `files/FileRepository.kt`, or, if it must stand alone, name the file after it (`Trips.kt`).

## Steps

The steps are in two files next to this one, so that they survive a compaction (Claude Code keeps only the first
5,000 tokens of a skill after one).

1. Server (migration, table and DTOs, repository, routes, API description, server tests): **read
   [references/1-server.md](references/1-server.md) now and follow it.** Read it again if the conversation was compacted
   or resumed during these steps.
2. Client (`core/api` model, client repository, ViewModel, screen, Maestro step): **read
   [references/2-client.md](references/2-client.md) now and follow it.** Read it again if the conversation was
   compacted or resumed during these steps.

## Done when

- The new migration is `V<highest + 1>`; every new table has `space_id UUID NOT NULL REFERENCES spaces(id) ON DELETE
  CASCADE`, user columns are `UUID REFERENCES users(id)` (who added a row `ON DELETE SET NULL`), the template's
  migrations are unchanged and `MigrationTest` lists the new table.
- The feature is in `server/.../feature/<name>/`; its routes are under `/api/v1` and registered in `Application.kt`;
  every handler calls `call.requireUser()` first and `requireRole` (VIEWER reads, EDITOR writes); a row the caller
  may not see answers 404, never 403; lists page with `limit` and `cursor`.
- The new paths and schemas are in `OpenApiSpec.kt` and the paths in `OpenApiTest`.
- The IDOR and validation tests cover no token, another user, a non-member, a viewer's write and bad input, and
  `./gradlew :server:build --console=plain` passes.
- The `core/api` models use the server's JSON names, every new route and model is in `ApiContractTest`'s lists, and
  `cmp-gates` is green (`allTests` runs `ApiContractTest` against the server's description).
- The client repository uses `BaseRepository` and `@Named(BACKEND_CLIENT)`, the screen follows `SelectedSpace`, and
  nothing changed under `core/auth`, `feature/account`, `feature/sharing` (except `SharingConfig.ENABLED`) or the
  server's `auth/`, `sharing/`, `users/`, `files/` and `plugins/`.
- `server/SECURITY-CHECKLIST.md` is gone through.
