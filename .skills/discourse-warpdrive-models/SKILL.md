---
name: discourse-warpdrive-models
description: Use when creating a new WarpDrive-backed frontend model, or when reading, using, or changing a model already converted to WarpDrive (anything under frontend/discourse/app/data or extending RestCompatModel/WarpRestModel)
---

# WarpDrive models

`service:warp-store` (`services/warp-store.js`) is a second data store alongside the legacy `service:store`, built on `@warp-drive/*` in LegacyMode with a JSON:API cache. Migrated models live in `frontend/discourse/app/data/`:

- `schemas/` — one resource schema per type, registered in `schemas/index.js`
- `normalize.js` + `jsonapi-utils.js` — Discourse REST payloads → JSON:API documents
- `builders/` — request objects, one file per resource
- `handlers/discourse-rest.js` — the sole network handler; routes through `ajax()`
- `warp-rest-model.js` — `WarpRestModel` wrapper base, plus `warpStore()`, `requestMany`/`requestOne`, `defineFieldForwarders`
- `rest-compat.js` — `RestCompatModel`, temporary legacy `RestModel` surface (`get`/`set`/`setProperties`, drafts, legacy adapter save path)
- `extra-attributes.js` — retains payload keys no schema declares (migration safety net)

A model is converted if its class in `app/models/` extends `RestCompatModel` (or `WarpRestModel` directly) and its schema is listed in `schemas/index.js`.

## Note: Schemas must be complete

A record is a proxy over the cache; reading a field the schema doesn't declare **throws in dev/test and returns `undefined` in production**. `Object.keys`, `for...in`, and `toJSON` see only schema fields. Therefore:

- Declare more attributes than seems necessary — a field only one endpoint sends still needs a line.
- To find every field, read the Ruby serializers (`app/serializers/`, including subclasses and `add_to_serializer` calls) and the API JSON schemas (`spec/requests/api/schemas/json/`) — not just one sample payload.
- Anything still arriving via `extra-attributes.js` is unfinished work, not a pattern to rely on.

## Creating a new model

1. **Schema** — `data/schemas/<type>.js`, using `withDefaults` + `attrs`/`belongsTo` from `schemas/helpers.js`. Annotate with `/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */` (avoids a TS2883 d.ts issue). Register it in `schemas/index.js`.
2. **Normalizer** — in `data/normalize.js` (or a per-resource file), build `{ data, included, meta }`. Use `resourceFrom(type, Schema, raw)` for the resource object (it also feeds the extras registry; pass an explicit `id` for sub-resources), `indexIncluded` + `maybeRelate` for relationships — `maybeRelate` drops pointers with no matching `included` entry, on purpose. Absent payload → `{ data: null }`, never `{ data: [] }` for single-record ops (wrap with the `recordOnly` pattern).
3. **Builders** — `data/builders/<resource>.js` using `readMany`/`readOne`/`createOne`/`updateOne`/`deleteOne` from `builders/helpers.js`; they carry the `op` and the `data: { type, id }` the cache needs. RPC-style endpoints (toggles, bulk ops) are plain inline `{ url, method, options }` objects with no `op`.
4. **Model class** — in `app/models/`, extend `RestCompatModel` (only extend `WarpRestModel` directly if no caller uses the legacy store/`get`/`set` API):

   ```js
   export default class Badge extends RestCompatModel {
     static type = "badge";
     static normalize = normalizeBadgesPayload;
     static builders = {
       list: findBadges,
       one: findBadge,
       save: saveBadge,
       delete: deleteBadge,
     };
     // custom getters here take precedence over forwarders
   }
   defineFieldForwarders(Badge, BadgeSchema);
   ```

   Other subclass hooks:
   - endpoints beyond plain CRUD — own statics over `requestMany`/`requestOne` (see `UserBadge.findByUsername`), not more `builders` keys
   - `static munge(json)` — massages JSON on legacy `_hydrate`
   - `primaryKey` — `TagNotification` uses `"name"`
   - `__resource` override, for models with their own ingest path — call `_applyExtraAttributes(id)` after pushing, and read `__ownResource` in anything the base constructor reaches, since subclass fields aren't initialized during `super()`

5. Run the model's qunit tests plus acceptance tests for its screens.

Relations to **unmigrated** models (User, Topic, …) are not relationships: store the raw embedded object as a plain attribute (see `bookmark.js` `user`, or `userBadgeResource` inlining sideloads), optionally wrapping it in the legacy model class in a getter or `create`.

## Working with a converted model

Reading and mutating:

- Fields are prototype forwarders to the cached record: `badge.name` reads, `badge.name = x` writes (LegacyMode records are mutable). Relationships are read-only through the wrapper.
- Legacy `get("a.b")` / `set` / `setProperties` still work via `RestCompatModel`.
- Ids are strings in the cache; the `@id` forwarder (`schema.identity.name`, usually `id`) coerces numeric ones back to numbers. `peekRecord` needs `String(id)`.
- Wrap a nested cached resource in its own model class in a getter when callers need that class's getters (`get badge() { return new Badge(this.__resource.badge) }`).
- Probe field existence by reading (`record.foo !== undefined`), never with `in` — the `has` trap on draft `trackedObject`s is unreliable and can hang headless qunit.
- List results are arrays with document `meta` assigned onto them (`result.grant_count`).

Fetching and persisting:

- `Model.findAll(opts)` / `Model.findById(id)` — via `builders.list`/`one`. Anything else: `requestMany(this, someBuilder(...))` / `requestOne(...)`.
- `Model.createFromJson(json)` — synchronous ingest for preloaded/embedded payloads; `record.updateFromJson(json)` re-pushes and re-adopts.
- Legacy `store.createRecord(type, attrs)` still works: it produces a _draft_ wrapper (`__isLocalDraft`, attrs in a `trackedObject`, undeclared keys readable). After `save()` the wrapper adopts the cached record and strict schema reads apply.
- `record.save(data)` has two paths: with `static builders.save` it goes through WarpDrive (`store.request`); without, it falls back to the legacy adapter pipeline. Both fire `addModelCallback` hooks and merge `addModelSaveProperty` extras.
- `record.destroy()` (builder path) vs `record.destroyRecord()` (legacy adapter path).
- One-off actions: `warpStore().request(someBuilder(...))` with an inline builder. A builder with no normalizer discards the response body (the handler returns `{ data: null }`) — callers needing it use `ajax` directly, as `UserBadge#revoke` does.
- Optimistic updates: `store.push({ data: { type, id: String(id), attributes } })`, then `this._adoptResource(this.id)` so a draft wrapper sees the new value; push the previous attributes back if the request rejects (`UserBadge#favorite`).

Plugin-extension APIs (`api.addModelField`/`Getter`/`Method`/…) still work — fields land as tracked properties on the wrapper, not in the cache. Schema-contributed plugin fields are planned but **not built** — don't design anything that depends on them.

## Changing a converted model

- **New server field**: add one line to the schema (`attrs(...)`) — `resourceFrom` picks it up automatically.
- **New client-only field**: also declare it in the schema (cheap, and keeps reads legal); mark it with a comment saying who sets it.
- **New relationship**: schema `belongsTo` + normalizer `maybeRelate` + push the related resource into `included`. Only between migrated types.
- **New endpoint**: add a builder; CRUD shapes use `builders/helpers.js`, RPC shapes are inline objects.
- **Derived values**: plain getters on the model class — define them before `defineFieldForwarders` runs. It skips any name that resolves anywhere on the prototype chain, which is also what stops a legacy-derived schema field called `save`/`get`/`destroy` from shadowing a base method.
- Prefer data-layer fixes (normalizer, schema, builder, compat layer) over touching consumers (routes, controllers, components) — the migration's goal is unchanged call sites.
- Shedding `RestCompatModel` for a model is the end state: only after no caller uses `get`/`set`/`store.createRecord`/legacy `save`.
