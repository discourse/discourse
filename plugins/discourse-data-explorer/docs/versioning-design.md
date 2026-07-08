# JSON:API Kit — Versioning Design

**Status:** design in progress (pairing sessions, 2026-07). Nothing here is built yet.
**References:** [Stripe versioning](./stripe-api-versioning-reference.md) · [Cadwyn review](./cadwyn-review.md) · [gem evaluation](./versioning-gem-evaluation.md) · [exploration doc](./api-modernization-exploration.md) (Part 4).

---

## 0. Decisions so far

- **Date-based versioning** (Stripe-style), built into the Kit — we own the design ([gem evaluation](./versioning-gem-evaluation.md) verdict).
- **Transport:** mandatory `Discourse-Api-Version: YYYY-MM-DD` request header from day one. Missing/invalid → 400 whose body teaches the current version. The resolved version is echoed back in a response header. No per-API-key pin (the mandatory header *is* the pin, client-side; a server-side default could be added later, additively). No `latest` alias.
- **Resolution: snap down** — any valid date resolves to the newest version ≤ it. Reject dates before the first version, and dates in the future (relative to the server's today): a future pin would silently re-resolve to a different contract once the next version ships — exactly the drift versioning exists to kill. *(Refines an earlier note that said "after the latest version → 400" — that was wrong: a date after the latest release but not in the future is the normal case for a freshly integrated client, and snaps down.)*
- **Always-latest internal representation.** Controllers, services, serializers only ever speak the newest shape. Version logic exists in exactly two places: `VersionChange` classes and the pipeline that applies them. Nothing else may branch on version (grep-able invariant).
- **Transforms are representation-only** (the bucket taxonomy): (1) reshapes of the same facts → transform; (2) meaning changed but the old value is cheap to keep → keep it in the model, transform picks by date; (3) behavior/data genuinely changed → *not* a transform → new endpoint/resource. Never version stored data.
- **Targeting is by JSON:API resource `type`** (the pipeline walks the typed document — `data` + `included`), plus a `document` scope for top-level members (`meta`, `links`, …). **JSON:API endpoints only** — non-JSON:API responses (e.g. query `run` results) are out of scope; endpoints wanting versioning must become JSON:API resources.
- **One `VersionChange` = `up` + `down`** (AR-migration feel). No separate `migrate` method — because we transform the serializer's output *hash before JSON-encoding* (never re-parse JSON we just built), `down` already *is* the pure data transform, and the pipeline stays invocable outside a controller (webhooks/jobs) for free.
- **Trust boundary:** machinery guarantees *shape* (the structure a transform targets exists), transforms don't validate, the Service::Base contract catches semantics — in latest terms, after up-migration.
- **`jsonapi_deserialize` loses its `only:` allowlist.** The service contract's declared attributes already are the allowlist (verified: `Query::Create` builds records from contract attributes, never raw params); the `only:` list duplicated that knowledge in latest terms and would silently drop an old client's renamed attributes before `up` existed to save them.
- Versioning subsystem stays **decoupled**: a self-contained unit (version type, registry, changes, walker) that `BaseController` calls at defined seams — so it survives the Kit's eventual post-experiment rewrite.

---

## 1. The acceptance trace: renaming `sql` → `query`

One synthetic breaking change, traced end-to-end through every surface. This is the acceptance script the implementation must satisfy.

### Setup

Illustrative timeline:

| Date | Event |
|---|---|
| `2026-08-01` | First public version of the API (v-day zero). |
| `2026-09-30` | Breaking change ships: the `queries` resource's `sql` attribute is renamed `query`. |

Two clients:
- **Old client** — pinned `2026-08-20` (integrated mid-August). Snaps down to `2026-08-01`. Its gap to latest contains one change: the rename.
- **New client** — pinned `2026-10-15`. Snaps down to `2026-09-30`. Empty gap → the pipeline is a no-op for it (fast path: skip the walk entirely).

### The change as code (strawman)

```ruby
module DiscourseDataExplorer
  module JsonApiKit
    module VersionChanges
      class RenameQueriesSqlToQuery < JsonApiKit::VersionChange
        version "2026-09-30"
        description "The `sql` attribute of the queries resource is renamed to `query`."

        resource :queries do
          # old client's input → latest shape (applied to request documents)
          up { |resource| resource[:attributes][:query] = resource[:attributes].delete(:sql) }
          # latest shape → old client's shape (applied to response documents)
          down { |resource| resource[:attributes][:sql] = resource[:attributes].delete(:query) }
        end
      end
    end
  end
end
```

**What else ships in that same commit** — the "latest" itself moves, and none of it knows versioning exists:
- `QuerySerializer`: `attributes :sql` → `attribute :query { |q| q.sql }` (wire rename only — the DB column stays `sql`; renaming a column is an orthogonal data-migration concern, never versioning's business).
- `Query::Create` (and later `Update`): contract attribute `:sql` → `:query`; `create_query` maps `sql: params.query`. The service params block *is* the latest request contract.
- The committed contract baseline (`json_api_kit_contract.json`) regenerates — the guard flags the removal of `sql` as backwards-incompatible, which is the cue that a `VersionChange` + new version date is required. (Guard/versioning integration: future work.)

The machinery only invokes `up`/`down` when the targeted structure exists (`data` present, `type` matches, `attributes` is a hash) — that's the "machinery is defensive so transforms don't have to be" rule in practice.

---

### Trace A — response down (GET)

**Old client:** `GET /data-explorer/api/queries` with `Discourse-Api-Version: 2026-08-20`.

```
resolve header → 2026-08-20 → snap → 2026-08-01 → gap = [RenameQueriesSqlToQuery]
   ↓
index action runs — filters/sort/pagination/Guardian — 100% version-free
   ↓
serializer emits the LATEST document hash (attributes include "query")
   ↓  (prune_empty_relationships!, then the new seam:)
pipeline.down(document, gap):
  walks data[] and included[], dispatching each resource object by its type;
  type == "queries" → applies down → attributes.query renamed back to sql
   ↓
render json: document          + echo header: Discourse-Api-Version: 2026-08-01
```

Wire effect (abbreviated):

```jsonc
// serializer output (latest)                    // after pipeline.down (what the old client gets)
{ "data": [ {                                    { "data": [ {
  "id": "42", "type": "queries",                   "id": "42", "type": "queries",
  "attributes": {                                  "attributes": {
    "name": "Top referrers",                         "name": "Top referrers",
    "query": "SELECT ...",          ──────▶           "sql": "SELECT ...",
    "last-run-at": "..." } } ] }                     "last-run-at": "..." } } ] }
```

Because dispatch is by `type`, the same rename applies wherever a `queries` resource appears — index, show, or sideloaded in `included` by some other endpoint — with zero per-endpoint wiring. **New client:** empty gap, document untouched, no walk performed.

### Trace B — query params up (sparse fieldsets)

**Old client:** `GET /data-explorer/api/queries?fields[queries]=name,sql` (header `2026-08-20`).

Without an up-rewrite, this fails *silently*: `jsonapi_fields` hands `["name", "sql"]` to the serializer, which knows no `sql` attribute → the field just doesn't match → response contains only `name`. No 400 (`reject_unknown_query_params!` checks filter/sort/include, not fields), no error — the client is quietly missing data it asked for. Then `down` has nothing to rename. Silent and wrong.

With the pipeline: the **first** before_action resolves the version and up-migrates the request — including the query-param surface. `fields[queries]` is type-keyed, so the `queries` up-context rewrites `sql` → `query`. The serializer then emits `query`, and Trace A's down renames it back. The client gets exactly `name` + `sql`.

Ordering constraint this fixes in stone: **version-resolve + up runs before `reject_unknown_query_params!` and before anything reads `params`.** (Had the renamed attribute been a declared sort/filter key, the same param rewrite applies; `queries` sorts are `name`/`last_run_at`/`username` today, so fieldsets are the realistic surface.)

### Trace C — request up (POST create)

**Old client:** `POST /data-explorer/api/queries` (header `2026-08-20`) with the *old* body:

```jsonc
{ "data": { "type": "queries",
            "attributes": { "name": "Slow topics", "sql": "SELECT ..." } } }
```

```
resolve → snap 2026-08-01 → gap = [rename]
   ↓
pipeline.up(params[:data], gap):     (oldest→newest — mirror order of down)
  data.type == "queries" → up → attributes.sql renamed to query
   ↓
jsonapi_deserialize(params)  → { "name" => "Slow topics", "query" => "SELECT ..." }
   ↓                            (no `only:` allowlist — the contract is the allowlist)
Query::Create.call(params: ..., guardian:)   — contract validates :query, latest terms
   ↓
on_success → render_resource(query, status: :created)
   ↓
pipeline.down(...)  → the 201 body serves `sql` back to the old client (same as Trace A)
```

Two things to notice: the create response flows through the same down pipeline as any read (one seam, `render_resource`), and the whole reason `up` must precede deserialization is visible — under the old `only:` allowlist (written in latest terms), the old client's `sql` would have been **silently dropped** before the service ever saw it.

### Trace D — validation errors down

**Old client:** same POST but with a blank `name`.

The contract fails in **latest terms**. Today's `render_validation_errors` builds:

```jsonc
{ "errors": [ { "status": "422", "title": "Invalid attribute",
                "detail": "Name can't be blank",
                "source": { "pointer": "/data/attributes/name" } } ] }
```

`name` wasn't renamed → no transform matches → passes through unchanged. But if the contract had rejected the *renamed* field (say a length cap on `:query`), the pointer would read `/data/attributes/query` — a field the old client has never heard of. The error pipeline must rewrite it to `/data/attributes/sql`.

**Design point the trace surfaces:** error documents are *typeless* — there's no `data.type` to dispatch on, so the walker's self-routing doesn't work here. The error down-pass needs context: the endpoint's primary resource type (which `BaseController` knows from its DSL config). That makes error migration the one context-dependent piece of the pipeline. *(Open micro-question: rewrite only `source.pointer` (the machine contract), or also the human `detail` prose? Lean: pointer only — `detail` is documentation, not contract.)*

### Trace E — header mechanics

| Request header | Result |
|---|---|
| *(missing)* | `400` — body teaches: current version, how to send the header, docs link |
| `2026-08-20` | `200`, resolved `2026-08-01` (snap down), echoed back |
| `2026-10-15` | `200`, resolved `2026-09-30`, empty gap → zero-cost passthrough |
| `2026-07-01` (before first version) | `400` — unknown version |
| `2027-01-01` (future) | `400` — future dates would silently re-resolve later; a client bug |
| `garbage` / `2026-13-45` | `400` — malformed |

### Trace F — invariants the trace pins down

1. **No version branches outside the subsystem.** After shipping the rename: `git grep -i version` in the serializer, service, and controller finds nothing new. The change lives in one `VersionChange` class.
2. **Additive stays free.** A plugin adding a namespaced key, or the team adding a new attribute, ships with *no* `VersionChange` and reaches every pinned client — the pipeline only knows about breaking changes.
3. **Latest is the fast path.** An empty gap skips the walk entirely — current clients pay ~zero for the existence of versioning.
4. **The pipeline is controller-independent.** `pipeline.down(document, to: version)` is callable on any document hash (webhook payloads, jobs) — no request/response objects required.

---

## 2. What the trace commits us to build

| # | Component | Role | Traces |
|---|---|---|---|
| 1 | `JsonApiKit::ApiVersion` | date parse/compare; snap-down; first/current bounds | E |
| 2 | `JsonApiKit::VersionChange` | DSL: `version`, `description`, `resource(type) { up/down }`, `document { … }` | all |
| 3 | Registry | dated, ordered set of changes; computes the gap for a resolved version; (plugin-extensible later) | all |
| 4 | Response pipeline (down) | walk `data`+`included`, dispatch by `type`, newest→oldest; document scope; fast path on empty gap | A, F |
| 5 | Request pipeline (up) | walk `params[:data]` + query-param surface (`fields[TYPE]`, sort/filter keys), oldest→newest | B, C |
| 6 | Error pipeline (down) | pointer rewrites, with endpoint-type context | D |
| 7 | `BaseController` seams | first before_action (resolve + up + echo); `render_resource` (down); `render_validation_errors` (error down); drop `only:` from `jsonapi_deserialize` | all |

**Build order (small increments):** ① components 1–3 (pure Ruby, spec'd in isolation) → ② response-down pipeline + controller seam (Traces A, E, F green — all reads benefit) → ③ request-up (B, C) → ④ errors (D).

## 3. Open questions (discovered, deliberately parked)

- **Error-pipeline context** — confirm "endpoint primary type" suffices, or whether error transforms want their own scope in the DSL.
- **Declarative shorthand** (`renamed_attribute`, `renamed_type`) — a rename touches four surfaces (body-up, body-down, params-up, pointers-down); a declarative tier collapses them and is the only clean answer for type renames (document-global rewrites). Deferred until the second rename makes the duplication real.
- **Contract-guard integration** — the schema guard should learn "breaking change detected → demand a `VersionChange` + version date" instead of just failing.
- **`fields[]` strictness** — unknown fieldset entries silently no-op today (pre-existing, versioning makes it visible). Separate decision.
- **Plugins** — namespaced-key convention + who owns the timeline (shared vs per-plugin): scheduled for its own exploration (see topic 186394 discussion).
