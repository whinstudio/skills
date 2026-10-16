---
name: cmp-backend
description: Use when adding the app's own data to the server in a project that has a `server/` module (generated with backend) — a new record type stored per space, its Flyway migration, Exposed table, repository and routes under authenticate with requireRole, the server test, the core/api model, the client repository on the backend client, and the ViewModel, screen and Maestro step that show it. Not for projects without `server/`.
argument-hint: "<entity and its fields>"
---

# Adding app data to the backend

Only for projects that have `server/` (Ktor, JVM) next to `core/api`, `core/auth`, `feature/account` and
`feature/sharing`. Without `server/` the project has no backend and this skill does not apply.

All data belongs to a **space**. Every user has a personal space (created on their first signed-in request); with
sharing on they can create more and invite others as EDITOR or VIEWER. Roles order VIEWER < EDITOR < OWNER: a
viewer reads, an editor adds, changes and deletes records and files, the owner also manages members and invites.

`<package>` below is the project's package (for example `com.example.trips`); paths are relative to the project root.
For the client layers follow `cmp-feature` and `cmp-code-rules` as for any feature; this skill adds what is
specific to the backend.

## Never touch

- `core/auth`, `feature/account`, `feature/sharing` (screens, repositories, `SelectedSpace`), apart from the one
  `SharingConfig.ENABLED` line below.
- `server/src/main/resources/db/migration/V1__core.sql` (users, spaces, space_members, invites, files). Flyway
  checks its checksum: an edited V1 fails every existing database.
- `requireRole` and `uuidOrNull` (`server/.../access/Access.kt`), the `authenticate(FIREBASE_AUTH)` setup and
  `touchUsers` in `Application.kt`, the core tables in `db/Tables.kt`.
- `BACKEND_CLIENT` and `buildBackendClient` in `core/network`: the backend client is a separate, named
  `HttpClient`; the app's unnamed one stays for other APIs.

## Sharing on or off

`feature/sharing/contract/.../SharingDestinations.kt` has `object SharingConfig { const val ENABLED = true }`.
If the app does not share data between users, set it to `false`: the space switcher and the Share button are
hidden and every record lives in the user's personal space. Routes and checks stay exactly as below; the
personal space is still a space.

## The reference pattern

`server/src/test/kotlin/<package>/server/ExampleItemRoutes.kt` (test sources only, nothing ships) is the shape to
copy: a table with `space_id`, routes under `/spaces/{id}/...`, `requireRole` first in every handler.
`ExampleItemRoutesTest.kt` next to it is the test to copy. Read both before writing.

## 1. Migration

`server/src/main/resources/db/migration/V2__<entity>.sql` (then `V3__...`, one new file per change; never edit a
migration that has run anywhere):

```sql
CREATE TABLE trips (
    id          UUID PRIMARY KEY,
    space_id    UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    cover_file  UUID REFERENCES files(id) ON DELETE SET NULL,
    created_by  TEXT REFERENCES users(uid) ON DELETE SET NULL,
    created_at  BIGINT NOT NULL
);
CREATE INDEX trips_space ON trips(space_id);
```

- Every table has `space_id UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE`: deleting a space or an
  account then removes its rows. A child table (a trip's stops) also carries `space_id`, not only the parent id.
- Times are `BIGINT` epoch milliseconds, ids `UUID`, uids `TEXT`, like V1.
- An image field is a `files` reference (`<name>_file UUID REFERENCES files(id) ON DELETE SET NULL`), never bytes
  or a URL in your table: uploads go through `POST /spaces/{id}/files`, which stores the file and its `files` row,
  and space deletion removes the files from disk.

## 2. Exposed table

Add an `object` to a new `server/src/main/kotlin/<package>/server/db/<Entity>Table.kt` (or next to the core
tables' style in `Tables.kt` without changing them). Flyway owns the schema; the object only describes it:

```kotlin
object Trips : Table("trips") {
    val id = uuid("id")
    val spaceId = uuid("space_id").references(Spaces.id, onDelete = ReferenceOption.CASCADE)
    val title = text("title")
    val coverFile = uuid("cover_file").references(Files.id, onDelete = ReferenceOption.SET_NULL).nullable()
    val createdBy = text("created_by").references(Users.uid, onDelete = ReferenceOption.SET_NULL).nullable()
    val createdAt = long("created_at")
    override val primaryKey = PrimaryKey(id)
}
```

Never `SchemaUtils.create` in main code; the table comes from the migration.

## 3. Repository

`server/.../db/<Entity>Repository.kt`, shaped like `FileRepository`: a class over `Database`, each method one
`transaction(db) { ... }`, every query filtered by `spaceId`.

```kotlin
/** Trips of a space. Callers check the caller's role first (`requireRole`) and pass `membership.spaceId`. */
class TripRepository(private val db: Database) {
    fun list(spaceId: UUID): List<Trip> = transaction(db) {
        Trips.selectAll().where { Trips.spaceId eq spaceId }.map { it.toTrip() }
    }

    fun delete(spaceId: UUID, id: UUID): Boolean = transaction(db) {
        Trips.deleteWhere { (Trips.spaceId eq spaceId) and (Trips.id eq id) } > 0
    }
}
```

- Update and delete by `spaceId` **and** `id`: an id from another space then matches nothing and answers 404.
- A `fileId` the client sends is checked with `FileRepository.get(id)`: it must exist and have the same
  `spaceId`, otherwise `badRequest(...)`.
- Add the repository to `Services` in `Application.kt` (a constructor parameter, and built in the
  `constructor(db, store)` line) so routes get it from `services`.

## 4. Routes

`server/.../routes/<Entity>Routes.kt`, `fun Route.tripRoutes(services: Services)`, mounted in `module()` inside
the existing `authenticate(FIREBASE_AUTH) { ... }` block, after `accountRoutes(services)`. Never outside it: a
route outside `authenticate` has no caller and no checks.

```kotlin
fun Route.tripRoutes(services: Services) {
    route("/" + ApiRoutes.trips("{id}")) {
        get {
            val membership = call.requireRole(services.spaces, call.parameters["id"].orEmpty(), Role.VIEWER)
            call.respond(services.trips.list(membership.spaceId))
        }
        post {
            val membership = call.requireRole(services.spaces, call.parameters["id"].orEmpty(), Role.EDITOR)
            val draft = call.receive<TripDraft>()
            // validate draft fields here (length, range); badRequest(...) on bad input
            call.respond(HttpStatusCode.Created, services.trips.add(membership.spaceId, membership.uid, draft))
        }
    }
}
```

- Every handler starts with `call.requireRole(services.spaces, <space id>, <role>)`: `Role.VIEWER` to read,
  `Role.EDITOR` to create, change or delete. It answers 404 for a non-member, a weaker role or a malformed id;
  never check membership by hand and never answer 403 (a space the caller cannot see must look like one that does
  not exist).
- Queries use the returned `membership.spaceId` and `membership.uid`, never the raw path value or a uid from the
  body.
- A route by record id (`/trips/{id}`) loads the record first, then calls `requireRole` with the record's
  `spaceId`, like `requireFile` in `FileRoutes.kt`; a missing record is `notFound()`.
- Receive a dedicated draft type with only the fields the client may set; never the stored row (no `spaceId`,
  `createdBy` or `id` from the client).
- Errors go through `notFound()` / `badRequest(...)` / `ApiException` from `Errors.kt`; the server's error
  handler answers with `ApiError`, never a stack trace.

## 5. Server test

`server/src/test/kotlin/<package>/server/<Entity>RoutesTest.kt`, copied from `ExampleItemRoutesTest.kt`. With the
routes in `module()` the test needs only `application { module(TestKeys.dbDeps()) }`; the V2 migration runs on
the embedded PostgreSQL (`TestDb`), so no `SchemaUtils`. `TestDb.reset()` in `@BeforeTest` empties your table
through the CASCADE from `spaces`.

Required cases, at least:

- **Non-member gets 404** on every route (read and write), and the body leaks nothing.
- **Viewer cannot write:** `client.join(owner, space.id, Role.VIEWER, viewer)`, then each POST, PATCH and DELETE as
  the viewer answers 404 and the data is unchanged; the viewer's GET works.
- An editor writes; a record created in one space does not show in another, and an id from another space answers
  404 on update and delete.
- No token answers 401; a malformed space id answers 404; bad input answers 400.
- With an image field: a `fileId` from another space is refused.

Helpers in `TestClient.kt`: `jsonClient()`, `jsonBody(token, body)`, `createSpace`, `invite`, `join`, `upload`;
tokens from `TestKeys.token("<uid>")`. `./gradlew allTests` runs these tests too (the first run downloads the
PostgreSQL binaries); `./gradlew :server:test` runs only the server.

## 6. `core/api` model

The wire types live in `core/api/src/commonMain/kotlin/<package>/core/api/` and are shared by the server and the
app: add `@Serializable data class Trip(...)` and `TripDraft(...)` (in `ApiModels.kt` or a new file), with ids as
`String` and an image as `fileId: String?`. Add the path to `ApiRoutes`, relative and without a leading `/`:

```kotlin
fun trips(spaceId: String) = "spaces/$spaceId/trips"
fun trip(id: String) = "trips/$id"
```

The server mounts `"/" + ApiRoutes.trips("{id}")`; the client calls `ApiRoutes.trips(space.id)`. Add the new
paths to `ApiModelsTest`.

## 7. Client repository

In the feature's `data` layer (`cmp-feature`), a repository over the backend client, like `KtorSpacesRepository`:

```kotlin
internal class KtorTripRepository(private val client: HttpClient) : BaseRepository(), TripRepository {
    override suspend fun list(spaceId: String): RestResult<List<Trip>> =
        request { client.get(ApiRoutes.trips(spaceId)) }
}
```

- Koin: `@Single fun provideTripRepository(@Provided @Named(BACKEND_CLIENT) client: HttpClient): TripRepository`.
  Without `@Named(BACKEND_CLIENT)` the call goes to the app's other client, with no token and the wrong base URL.
- Never add a token, a base URL or a second `HttpClient`: the backend client sends the signed-in user's token only
  to the backend and refreshes it once on a 401.
- Images: `normalizeImageForUpload(bytes)` from `core/image` (JPEG, at most 2048 px and 5 MB), then a multipart
  `POST ApiRoutes.files(spaceId)` → `UploadResult.fileId`, then save the record with that `fileId`. Show it with
  Coil from `ApiRoutes.file(fileId)` on the backend's base URL; the image loader already adds the token.

## 8. ViewModel

- Inject `SelectedSpace` (`feature/sharing/contract`, `@Provided`) and collect `selectedSpace.current`; load the
  list for `current.id` each time it changes, nothing while it is `null` (signed out, or the first refresh has not
  answered). Use `collectLatest` so a switch cancels the old load.
- Gate write actions on the role: `space.role.atLeast(Role.EDITOR)` hides add, edit and delete for viewers. The
  server still enforces it; the UI only avoids offering what will fail.
- A 404 after a space switch or a removal means the space is gone for this user: call `selectedSpace.refresh()`
  (it falls back to the personal space) instead of showing an error.

## 9. Screen

- Lists the selected space's records; with `SharingConfig.ENABLED` the space's name is visible (title or header)
  so the user knows whose data they see.
- Empty, loading and error states as in `cmp-feature`; strings in `core/multilang` (backend projects always have
  it).
- Add a `testTag` to the list, the add button and each row (`<Name>TestTags`, see `cmp-maestro`).

## 10. Maestro step

Pass this to `cmp-maestro`. The flow signs in first, with a test account from the environment, never written into
the flow:

```yaml
appId: <applicationId>
---
- launchApp
# email sign-in: tap the email field, inputText: ${TEST_EMAIL}; the password field, inputText: ${TEST_PASSWORD}; submit
- assertVisible:
    id: "trips_list"
```

Run it with `maestro test -e TEST_EMAIL=... -e TEST_PASSWORD=... .maestro/<flow>.yaml` against a build that talks
to a running server (`./gradlew :server:runLocal` for a debug build). Select the sign-in fields by the login
screen's test tags; if they have none, report that as open instead of editing `feature/account`. No credentials,
tokens or Firebase project ids in any committed file.

## Done when

- The new migration is `V2+`, every new table has `space_id` with `ON DELETE CASCADE`, and V1 is unchanged.
- Every new route is inside `authenticate(FIREBASE_AUTH)` and every handler calls `requireRole` (VIEWER reads,
  EDITOR writes).
- The server test covers non-member 404 and viewer-cannot-write, and `cmp-gates` is green (`allTests` includes the
  server).
- The client repository uses `@Named(BACKEND_CLIENT)`, the screen follows `SelectedSpace`, and nothing under
  `core/auth`, `feature/account` or `feature/sharing` changed except `SharingConfig.ENABLED`.
