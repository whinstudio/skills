# cmp-backend: client steps (7–11)

Part of the `cmp-backend` skill; `<package>`, `server/.../` and the pattern are defined in its `SKILL.md`.

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
- A 409 `QUOTA_EXCEEDED` is a full quota, not a bug. The template's writes that hit one are an upload, a space
  create, an invite create and an invite accept; another write only does once you add a quota check to it. The app's
  `DataError.Http` carries `apiCode` only, not the body's `quota`, so tell which quota is full by the call that
  failed (an upload means storage), say so with a string in `core/multilang`, and keep what the user entered.

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
