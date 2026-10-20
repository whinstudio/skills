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

## 1. Migration

`server/src/main/resources/db/migration/V<n>__<name>.sql`, where `<n>` is the highest `V<n>` already in that folder
plus 1 (list the folder; never assume the next number). One new file per change; never edit a migration that has
run anywhere.

```sql
-- Each trip belongs to one space: deleting the space, or its owner's account, deletes the trips.
-- The CHECKs repeat the API's limits. Times are epoch milliseconds.
CREATE TABLE trips (
    id          UUID PRIMARY KEY,
    space_id    UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    title       TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
    cover_file  UUID REFERENCES files(id) ON DELETE SET NULL,
    created_by  UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at  BIGINT NOT NULL,
    updated_at  BIGINT NOT NULL
);
-- Listing pages through a space's trips newest first, by (created_at, id).
CREATE INDEX trips_space_page ON trips(space_id, created_at DESC, id DESC);
```

- Every table has `space_id UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE`: deleting a space or an
  account then removes its rows. A child table (a trip's stops) also carries `space_id`, not only the parent id.
- A column naming a user is `UUID REFERENCES users(id)`: the server's own user id, never the Firebase uid, a
  copied name or an email. Who added a row is `ON DELETE SET NULL` (as `files.uploaded_by`), never `CASCADE`,
  which would delete shared data when that user deletes their account.
- Repeat the API's limits as `CHECK` constraints. Times are `BIGINT` epoch milliseconds, ids `UUID`.
- An image field is a `files` reference (`<name>_file UUID REFERENCES files(id) ON DELETE SET NULL`), never bytes
  or a URL in your table: uploads go through `POST /api/v1/files`, which stores the file and its `files` row, and
  space deletion removes the files from disk.
- Add the new table's name to the expected list in `server/src/test/.../MigrationTest.kt`; it lists every table
  after a clean migration and fails otherwise.

## 2. Table and DTOs

The table object goes at the top of `<Entity>Repository.kt` (see "The pattern"). Flyway owns the schema; the object
only describes it to Exposed. Never `SchemaUtils.create`.

```kotlin
// Mirrors db/migration/V<n>__trips.sql; Flyway owns the schema.
object Trips : Table("trips") {
    val id = uuid("id")
    val spaceId = uuid("space_id")
    val title = text("title")
    val coverFile = uuid("cover_file").nullable()
    val createdBy = uuid("created_by").nullable()
    val createdAt = long("created_at")
    val updatedAt = long("updated_at")
    override val primaryKey = PrimaryKey(id)
}
```

`<Entity>Dto.kt`: what goes over the wire, and a row type (`Trip`) for the repository.

```kotlin
@Serializable
data class TripResponse(
    val id: String,
    val spaceId: String,
    val title: String,
    val coverFileId: String?,
    val createdAt: Long,
    val updatedAt: Long,
)

/** One page, newest first; [nextCursor] is null on the last page. */
@Serializable
data class TripPage(val items: List<TripResponse>, val nextCursor: String?)

/** Only what a client may set; a missing title is reported like an empty one. */
@Serializable
data class TripDraft(val title: String = "", val coverFileId: String? = null)
```

- A draft or patch holds only the fields a client may set: never the id, the space, the user, the times or a role.
  The server's JSON setup (`ignoreUnknownKeys = false`) refuses a body with an unknown field, a field the server
  owns or a value of the wrong type before your code runs: the error handler answers 400 `BAD_REQUEST`
  "Malformed request body", without `fields`. That blocks mass assignment.
- Responses are built from the row (`toResponse()`), never the row or an internal object itself. Response fields
  have no defaults: the server does not encode defaults, so such a field would be missing on the wire.
- Validate every field of a well-formed body at the boundary in one function that returns all problems at once
  (`fun tripErrors(title: String): List<FieldError>`, lengths in characters with `codePointCount`); the route
  answers `badRequest("Invalid trip", errors)`, a 400 whose `fields` names each invalid field (empty, too long,
  out of range).

## 3. Repository

`<Entity>Repository.kt`, shaped like `FileRepository`: a class over `Database`, each method one
`transaction(db) { ... }`.

```kotlin
/** Trips. Nothing here checks a user: routes check the caller's role first (`requireRole`) and pass the space. */
class TripRepository(private val db: Database) {
    /** Up to [limit] trips of [spaceId], newest first, after [after] (from the start when null). */
    fun list(spaceId: UUID, limit: Int, after: TripCursor?): List<Trip> = transaction(db) {
        Trips.selectAll().where { Trips.spaceId eq spaceId }
            .apply { if (after != null) andWhere { before(after) } }
            .orderBy(Trips.createdAt to SortOrder.DESC, Trips.id to SortOrder.DESC)
            .limit(limit)
            .map { it.toTrip() }
    }

    /** The trip [id], or null; the route then checks the role in the trip's own space. */
    fun get(id: UUID): Trip? = transaction(db) {
        Trips.selectAll().where { Trips.id eq id }.singleOrNull()?.toTrip()
    }

    fun delete(spaceId: UUID, id: UUID): Boolean = transaction(db) {
        Trips.deleteWhere { (Trips.spaceId eq spaceId) and (Trips.id eq id) } > 0
    }
}
```

- `toTrip()`, `toResponse()`, `TripCursor`, `cursor()`, `before()`, `trips.add()`, `call.page()` and `newTrip()`
  in these examples are yours to write: a project generated with backend has no sample feature that defines them.
  The cursor, for example:

  ```kotlin
  /** The last row of a page; opaque on the wire (URL-safe Base64 of `createdAt:id`). */
  data class TripCursor(val createdAt: Long, val id: UUID) {
      fun encode(): String = Base64.getUrlEncoder().withoutPadding().encodeToString("$createdAt:$id".toByteArray())

      companion object {
          /** Null when [text] is not a cursor this server issued (the route answers 400). */
          fun decode(text: String): TripCursor? = runCatching {
              val (time, id) = String(Base64.getUrlDecoder().decode(text)).split(':', limit = 2)
              TripCursor(time.toLong(), UUID.fromString(id))
          }.getOrNull()
      }
  }

  // Strictly after [cursor] in the newest-first order; the id breaks ties within one millisecond.
  private fun before(cursor: TripCursor): Op<Boolean> =
      (Trips.createdAt less cursor.createdAt) or
          ((Trips.createdAt eq cursor.createdAt) and (Trips.id less cursor.id))
  ```

- Every list and every change filters by the space in the same query (`spaceId` **and** `id` for update and
  delete): an id from another space then matches nothing and answers 404.
- Lists page with `limit` (1..200, default 50) and an opaque `cursor`: the URL-safe Base64 of the last row's
  `createdAt:id`. Ask for `limit + 1` rows; the extra one says another page follows. A bad `limit` or a cursor the
  server did not issue is a 400 naming it. Never return an unbounded list.
- A `coverFileId` the client sends is checked with `FileRepository.get(id)`: it must exist and be in the same space,
  otherwise a 400 on that field.
- Build it next to the others in `module()` in `Application.kt` (`val trips = deps.db?.let(::TripRepository)`, after
  `val files = ...`) and register the routes inside the `routing { ... }` block's
  `if (users != null && files != null && spaces != null) { ... }`, after `fileRoutes(...)`:
  `trips?.let { tripRoutes(it, files, spaces) }`.

## 4. Routes

`<Entity>Routes.kt`. Every path is under `/api/v1`: a space's records at `/api/v1/spaces/{id}/<things>`, one
record at `/api/v1/<things>/{id}`.

```kotlin
/** The trip named by `{id}` if the caller's role in its space is at least [atLeast]; otherwise 404. */
private suspend fun ApplicationCall.requireTrip(trips: TripRepository, spaces: SpaceRepository, atLeast: Role): Trip {
    val id = uuidOrNull(parameters["id"].orEmpty()) ?: notFound()
    return (trips.get(id) ?: notFound()).also { requireRole(spaces, it.spaceId.toString(), atLeast) }
}

fun Route.tripRoutes(trips: TripRepository, files: FileRepository, spaces: SpaceRepository) {
    route("/api/v1/spaces/{id}/trips") {
        get {
            call.requireUser()
            val membership = call.requireRole(spaces, call.parameters["id"].orEmpty(), Role.VIEWER)
            val (limit, after) = call.page() // limit and cursor from the query; 400 on a bad one
            val rows = trips.list(membership.spaceId, limit + 1, after)
            val page = rows.take(limit)
            val next = if (rows.size > limit) page.last().cursor().encode() else null
            call.respond(TripPage(page.map { it.toResponse() }, next))
        }
        post {
            call.requireUser()
            val membership = call.requireRole(spaces, call.parameters["id"].orEmpty(), Role.EDITOR)
            val draft = call.receive<TripDraft>()
            // Validates (400 with fields, the cover file in this space) and builds the row with
            // membership.spaceId and membership.userId.value as created_by.
            val trip = newTrip(draft, membership, files)
            trips.add(trip)
            call.respond(HttpStatusCode.Created, trip.toResponse())
        }
    }
    route("/api/v1/trips/{id}") {
        get {
            call.requireUser()
            call.respond(call.requireTrip(trips, spaces, Role.VIEWER).toResponse())
        }
        delete {
            call.requireUser()
            val trip = call.requireTrip(trips, spaces, Role.EDITOR)
            if (!trips.delete(trip.spaceId, trip.id)) notFound()
            call.respond(HttpStatusCode.NoContent)
        }
    }
}
```

- Every handler calls `call.requireUser()` first, before it reads the body or looks anything up: no token, or a
  bad one, is 401.
- A space's data: `call.requireRole(spaces, <space id>, Role.VIEWER)` to read, `Role.EDITOR` to create, change or
  delete. It answers 404 for a non-member, a weaker role or an id that is not a UUID; never check membership by
  hand. Queries use the returned `membership.spaceId` and `membership.userId`, never the raw path value or an id
  from the body.
- A record by id loads the row first, then checks the role in the row's own space (`requireTrip`, like
  `requireFile` in `FileRoutes.kt`); a missing row is `notFound()`.
- **404, never 403:** a row the caller may not see answers exactly like one that does not exist, so ids cannot be
  probed.
- A PATCH changes only the fields the body names; to tell a left-out field from an explicit `null`, read the body
  as a `JsonObject` first, then decode the patch from it.
- Errors go through `notFound()`, `badRequest(message, fields)` and `ApiException` (`server/.../plugins/Errors.kt`);
  never put exception messages, SQL or stack traces in a response.
- A costly or security-sensitive route (bulk change, export, anything that sends mail) runs under
  `rateLimit(SENSITIVE_LIMIT) { ... }`. Nothing changes state on a GET. Never log tokens, emails, bodies or other
  personal data.

## 5. API description

The server's OpenAPI document is written by hand in code, `server/.../openapi/OpenApiSpec.kt`, and every new route
and schema must be in it: the app's `ApiContractTest` (step 7) checks the app against it, and the server's
`OpenApiTest` checks it against the route list.

- In `<Entity>OpenApi.kt`, write `internal fun JsonObjectBuilder.tripPaths()` and `tripSchemas()` with the helpers
  from `OpenApiSpec.kt` (`operation`, `returns`, `fails`, `pathParameters("Id")`, `jsonBody`, `schema`, `objectOf`,
  `arrayOf`, `string`, `uuid`, `int64`, `nullable()`). Paths are relative to `/api/v1`: `/spaces/{id}/trips` and
  `/trips/{id}`. A request schema is `objectOf(..., closed = true)`; a nullable response field is `.nullable()`.
- Name each schema after the app's model in `core/api` (`Trip`, `TripPage`, `TripDraft`), not after the server's
  DTO (`TripResponse`), as `FileResponse` is described as `File`: `ApiContractTest` looks every model up by that
  name (`Model("Trip", ...)`) and otherwise reports "not in the API description".
- A response schema lists **every** field in `required`, the nullable ones included: the server always sends each
  field (a null as `null`), and `ApiContractTest` reports a field left out of `required` whose model field has no
  default ("the server may leave it out, the model has no default"). A request schema requires only what the client
  must send.
- Call `tripPaths()` in the `paths` block of `openApiSpec()` and `tripSchemas()` in the `schemas` block of
  `components()`.
- Add the new paths to the expected set of `listsEveryRouteAndNothingElse` in `server/src/test/.../OpenApiTest.kt`.

```kotlin
internal fun JsonObjectBuilder.tripPaths() {
    putJsonObject("/spaces/{id}/trips") {
        put("parameters", pathParameters("Id"))
        put("get", operation("A space's trips, newest first, a page at a time (VIEWER or above)") {
            returns(OK, "One page", schema("TripPage"))
            fails(BadRequest, Unauthorized, NotFound)
        })
    }
}

internal fun JsonObjectBuilder.tripSchemas() {
    // Every field, coverFileId (nullable) included
    put("Trip", objectOf(listOf("id", "spaceId", "title", "coverFileId", "createdAt", "updatedAt")) {
        put("id", uuid())
        put("spaceId", uuid())
        put("title", string())
        put("coverFileId", uuid().nullable())
        put("createdAt", int64())
        put("updatedAt", int64())
    })
}
```

## 6. Server tests

`<Entity>IdorTest.kt` and `<Entity>ValidationTest.kt` in
`server/src/test/kotlin/<package as folders>/server/feature/<name>/`:

```kotlin
class TripIdorTest {
    @BeforeTest
    fun clean() {
        TestDb.reset()
    }

    private fun withApp(block: suspend ApplicationTestBuilder.(HttpClient) -> Unit) = testApplication {
        application { module(authDeps()) }
        block(jsonClient())
    }

    private val alice = TestKeys.token(sub = "alice")
    private val bob = TestKeys.token(sub = "bob")

    @Test
    fun viewerReadsButCannotWrite() = withApp { client ->
        val space = client.sharedSpace(alice, "Trip", bob to Role.VIEWER)
        // alice adds a trip; bob's GET works, bob's POST, PATCH and DELETE answer 404 and change nothing
    }
}
```

The migrations run on the embedded PostgreSQL (`TestDb`), so no `SchemaUtils`; `TestDb.reset()` empties every
table. Required cases, at least:

- **No token** answers 401 on every route.
- **IDOR:** another user's GET, PATCH and DELETE by id answer 404 and change nothing; a non-member on the space's
  routes gets 404; a member of another space gets 404; the body leaks nothing (`errorCode()` is `NOT_FOUND`).
- **Viewer cannot write:** each POST, PATCH and DELETE as a VIEWER answers 404 and the data is unchanged; the
  viewer's GET works.
- A path id that is not a UUID answers 404.
- **Validation:** for every rule an empty and a too long value answer 400 with `fields` naming each invalid field
  (all of them at once); a wrong type, an unknown field and a field the server owns (`id`, `spaceId`, `createdBy`)
  answer 400 (a malformed body, no `fields`: check only the status) and change nothing; a bad `limit` or `cursor`
  is 400 and the pages do not overlap.
- With an image field: a `coverFileId` from another space is refused.

Helpers (in the package `<package>.server`): `jsonClient()`, `jsonBody(token, body)`, `errorCode()`,
`upload(token, spaceId = ...)` in `TestClient.kt`; `createSpace`, `sharedSpace(owner, name, token to Role.X)`,
`personalSpace`, `invite`, `accept` and `userId` in `SharingTestClient.kt`; `authDeps()` in `TestApp.kt`; tokens
from `TestKeys.token(sub = "<name>")`.

Check the server with `./gradlew :server:build --console=plain` from the project root: it compiles the server and
runs its tests and its detekt (the first run downloads the PostgreSQL binaries once). `server/` is an included
build: `allTests` and the `cmp-gates` gates do not run it, so run this yourself.

## 7. `core/api` model

The server and the app share no code: the server's DTOs (step 2) and the app's models in
`core/api/src/commonMain/kotlin/<package as folders>/core/api/` are two copies of one JSON contract. Add the models
to `ApiModels.kt` with the server's JSON names and types:

```kotlin
@Serializable
data class Trip(
    val id: String,
    val spaceId: String,
    val title: String,
    val coverFileId: String?,
    val createdAt: Long,
    val updatedAt: Long,
)

@Serializable
data class TripPage(val items: List<Trip>, val nextCursor: String?)

@Serializable
data class TripDraft(val title: String, val coverFileId: String? = null)
```

- Ids are `String`, an `int64` is `Long` (never `Int`), a field the server may send as `null` is nullable, and a
  field the server's request schema requires has no default (the client's JSON does not encode defaults, so it
  would never be sent).
- Add the paths to `ApiRoutes.kt`, relative and without a leading `/` (the client's base URL ends with `/api/v1/`):

```kotlin
fun trips(spaceId: String) = "spaces/$spaceId/trips"
fun trip(id: String) = "trips/$id"
```

- Add every new route with its method to `CLIENT_ROUTES` and every model with its schema name to `MODELS` in
  `core/api/src/androidHostTest/.../ApiContractTest.kt` (`Model("Trip", Trip.serializer().descriptor,
  response = true)`, `Model("TripDraft", TripDraft.serializer().descriptor, response = false)`), and the routes to
  `routesHaveNoLeadingSlash` in `ApiModelsTest.kt`. `ApiContractTest` runs the server's `writeOpenApi` and fails on
  a route, field, nullability or type the server does not have.

## 8. Client repository

In the feature's `data` layer (`cmp-feature`), a repository over the backend client, like `KtorSpacesRepository`:

```kotlin
internal class KtorTripRepository(private val client: HttpClient) : BaseRepository(), TripRepository {
    override suspend fun list(spaceId: String, cursor: String?): RestResult<TripPage> =
        request { client.get(ApiRoutes.trips(spaceId)) { cursor?.let { parameter("cursor", it) } } }
}
```

- Koin: `@Single fun provideTripRepository(@Provided @Named(BACKEND_CLIENT) client: HttpClient): TripRepository`.
  Without `@Named(BACKEND_CLIENT)` the call goes to the app's other client, with no token and the wrong base URL.
- Never add a token, a base URL or a second `HttpClient`: the backend client sends the signed-in user's token only
  to the backend and refreshes it once on a 401.
- Images: `normalizeImageForUpload(bytes)` from `core/image` (JPEG, at most 2048 px and 5 MB), then a multipart
  `POST ApiRoutes.FILES` with the `file` part and a `spaceId` field → `FileInfo.id`, then save the record with that
  id. Show it with Coil from `ApiRoutes.file(id)` on the backend's base URL; the image loader already adds the token.

## 9. ViewModel

- Inject `SelectedSpace` (`feature/sharing/contract`, `@Provided`) and collect `selectedSpace.current`; load the
  list for `current.id` each time it changes, nothing while it is `null` (signed out, or the first refresh has not
  answered). Use `collectLatest` so a switch cancels the old load.
- Gate write actions on the role: `space.role.atLeast(Role.EDITOR)` hides add, edit and delete for viewers. The
  server still enforces it; the UI only avoids offering what will fail.
- A 404 after a space switch or a removal means the space is gone for this user: call `selectedSpace.refresh()`
  (it falls back to the personal space) instead of showing an error.

## 10. Screen

- Lists the selected space's records; with `SharingConfig.ENABLED` the space's name is visible (title or header)
  so the user knows whose data they see.
- Empty, loading and error states as in `cmp-feature`; strings in `core/multilang` (backend projects always have
  it).
- Add a `testTag` to the list, the add button and each row (`<Name>TestTags`, see `cmp-maestro`).

## 11. Maestro step

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
to a running server (for a debug build, `./gradlew :server:runLocal` from the project root, with
`firebaseProjectId=<id>` in `.local-server/config.properties`). Select the sign-in fields by the login screen's test
tags; if they have none, report that as open instead of editing `feature/account`. No credentials, tokens or
Firebase project ids in any committed file.

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
