# cmp-backend: server steps (1–6)

Part of the `cmp-backend` skill; `<package>`, `server/.../` and the pattern are defined in its `SKILL.md`.

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
- A list that can grow pages with `limit` (1..200, default 50) and an opaque `cursor`: the URL-safe Base64 of the
  last row's `createdAt:id`. Ask for `limit + 1` rows; the extra one says another page follows. A bad `limit` or a
  cursor the server did not issue is a 400 naming it. A small list with a fixed upper bound (like the invites list,
  at most 200) may answer in one plain array. Never return an unbounded list.
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
- A paged GET names its query parameters: `limit` (integer, 1..200, default 50: the bounds the route checks) and
  `cursor` (a string, the previous page's `nextCursor`). `OpenApiSpec.kt` has no query parameter helper; write a
  private `queryParameter` in `<Entity>OpenApi.kt` and pass the list as `operation(..., parameters = ...)`.
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
private const val MAX_PAGE = 200
private const val DEFAULT_PAGE = 50

private fun queryParameter(name: String, schema: JsonObject, description: String? = null) = buildJsonObject {
    put("name", name)
    put("in", "query")
    description?.let { put("description", it) }
    put("schema", schema)
}

internal fun JsonObjectBuilder.tripPaths() {
    val listParameters = buildJsonArray {
        add(queryParameter("limit", buildJsonObject {
            put("type", "integer")
            put("minimum", 1)
            put("maximum", MAX_PAGE)
            put("default", DEFAULT_PAGE)
        }))
        add(queryParameter("cursor", string(), "The nextCursor of the previous page"))
    }
    putJsonObject("/spaces/{id}/trips") {
        put("parameters", pathParameters("Id"))
        val summary = "A space's trips, newest first, a page at a time (VIEWER or above)"
        put("get", operation(summary, parameters = listParameters) {
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
build that `allTests` does not run; in a Compass project `cmp-gates` runs it as its server gate, elsewhere run it
yourself.
