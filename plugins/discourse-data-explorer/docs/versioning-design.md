# JSON:API Kit — Versioning Design

**Status:** design in progress (pairing sessions, 2026-07). Nothing here is built yet.
**References:** [Stripe versioning](./stripe-api-versioning-reference.md) · [Cadwyn review](./cadwyn-review.md) · [gem evaluation](./versioning-gem-evaluation.md) · [exploration doc](./api-modernization-exploration.md) (Part 4) · [plugins design](./plugins-design.md).

---

## 0. Decisions so far

- **Date-based versioning** (Stripe-style), built into the Kit — we own the design ([gem evaluation](./versioning-gem-evaluation.md) verdict).
- **Transport:** mandatory `Api-Version: YYYY-MM-DD` request header from day one (renamed from `Discourse-Api-Version` after review — consistency with the existing `Api-Key`/`Api-Username` headers). Missing/invalid → 400 whose body teaches the current version. The resolved version is echoed back in a response header. No per-API-key pin (the mandatory header *is* the pin, client-side; a server-side default could be added later, additively). No `latest` alias.
- **Resolution: snap down** — any valid date resolves to the newest version ≤ it. Reject dates before the first version, and dates in the future (relative to the server's today): a future pin would silently re-resolve to a different contract once the next version ships — exactly the drift versioning exists to kill. *(Refines an earlier note that said "after the latest version → 400" — that was wrong: a date after the latest release but not in the future is the normal case for a freshly integrated client, and snaps down.)*
- **Always-latest internal representation.** Controllers, services, serializers only ever speak the newest shape. Version logic exists in exactly two places: `VersionChange` classes and the pipeline that applies them. Nothing else may branch on version (grep-able invariant).
- **Transforms are representation-only** (the bucket taxonomy): (1) reshapes of the same facts → transform; (2) meaning changed but the old value is cheap to keep → keep it in the model, transform picks by date; (3) behavior/data genuinely changed → *not* a transform → new endpoint/resource. Never version stored data.
- **Targeting is by JSON:API resource `type`** (the pipeline walks the typed document — `data` + `included`), plus a `document` scope for top-level members (`meta`, `links`, …). **JSON:API endpoints only** — endpoints wanting versioning must serve JSON:API documents. NB (clarified 2026-07-27): this is not a CRUD restriction. An action-shaped endpoint becomes a resource — running a query is a `query-runs` resource created by `POST`, whose attributes carry the result — so migrating an area means migrating all of it. What stays outside is a response that is not a JSON:API document at all (a CSV download, for instance).
- **One `VersionChange` = `up` + `down`** (AR-migration feel). No separate `migrate` method — because we transform the serializer's output *hash before JSON-encoding* (never re-parse JSON we just built), `down` already *is* the pure data transform, and the pipeline stays invocable outside a controller (webhooks/jobs) for free.
- **Trust boundary:** machinery guarantees *shape* (the structure a transform targets exists), transforms don't validate, the Service::Base contract catches semantics — in latest terms, after up-migration.
- **`jsonapi_deserialize` loses its `only:` allowlist.** The service contract's declared attributes already are the allowlist (verified: `Query::Create` builds records from contract attributes, never raw params); the `only:` list duplicated that knowledge in latest terms and would silently drop an old client's renamed attributes before `up` existed to save them.
- Versioning subsystem stays **decoupled**: a self-contained unit (version type, registry, changes, walker) that `BaseController` calls at defined seams. To be clear about expectations: everything here is spike code and will likely be redone (at least in part) when the Kit leaves the experiment phase — the decoupling buys a small rewrite blast radius, and the durable artifact is this design, not the code.

---

## 1. The acceptance trace: renaming `sql` → `query`

One synthetic breaking change, traced end-to-end through every surface. This is the acceptance script the implementation must satisfy.

### Setup

Illustrative timeline:

| Date | Event |
|---|---|
| `2026-05-01` | First public version of the API (v-day zero). |
| `2026-06-15` | Breaking change ships: the `queries` resource's `sql` attribute is renamed `query`. |

Two clients:
- **Old client** — pinned `2026-05-20` (integrated mid-May). Snaps down to `2026-05-01`. Its gap to latest contains one change: the rename.
- **New client** — pinned `2026-07-01`. Snaps down to `2026-06-15`. Empty gap → the pipeline is a no-op for it (fast path: skip the walk entirely).

### The change as code (strawman)

```ruby
module DiscourseDataExplorer
  module JsonApiKit
    module VersionChanges
      class RenameQueriesSqlToQuery < JsonApiKit::VersionChange
        version "2026-06-15"
        description "The `sql` attribute of the queries resource is renamed to `query`."

        resource :queries do
          renamed_attribute from: :sql, to: :query
        end
      end
    end
  end
end
```

*(Originally written as hand-written `up`/`down` blocks; the declarative tier — see the section below —
subsumed them: the machinery derives all four surfaces from the declared fact.)*

**What else ships in that same commit** — the "latest" itself moves, and none of it knows versioning exists:
- `QuerySerializer`: `attributes :sql` → `attribute :query { |q| q.sql }` (wire rename only — the DB column stays `sql`; renaming a column is an orthogonal data-migration concern, never versioning's business).
- `Query::Create` (and later `Update`): contract attribute `:sql` → `:query`; `create_query` maps `sql: params.query`. The service params block *is* the latest request contract.
- The committed contract baseline (`json_api_kit_contract.json`) regenerates — the guard flags the removal of `sql` as backwards-incompatible, which is the cue that a `VersionChange` + new version date is required. (Guard/versioning integration: future work.)

The machinery only invokes `up`/`down` when the targeted structure exists (`data` present, `type` matches, `attributes` is a hash) — that's the "machinery is defensive so transforms don't have to be" rule in practice.

---

### Trace A — response down (GET)

**Old client:** `GET /data-explorer/api/queries` with `Api-Version: 2026-05-20`.

```
resolve header → 2026-05-20 → snap → 2026-05-01 → gap = [RenameQueriesSqlToQuery]
   ↓
index action runs — filters/sort/pagination/Guardian — 100% version-free
   ↓
serializer emits the LATEST document hash (attributes include "query")
   ↓  (prune_empty_relationships!, then the new seam:)
pipeline.down(document, gap):
  walks data[] and included[], dispatching each resource object by its type;
  type == "queries" → applies down → attributes.query renamed back to sql
   ↓
render json: document          + echo header: Api-Version: 2026-05-01
```

Wire effect (abbreviated):

```jsonc
// serializer output (latest)                    // after pipeline.down (what the old client gets)
{ "data": [ {                                    { "data": [ {
  "id": "42", "type": "queries",                   "id": "42", "type": "queries",
  "attributes": {                                  "attributes": {
    "name": "Top referrers",                         "name": "Top referrers",
    "query": "SELECT ...",          ──────▶           "sql": "SELECT ...",
    "last_run_at": "..." } } ] }                     "last_run_at": "..." } } ] }
```

Because dispatch is by `type`, the same rename applies wherever a `queries` resource appears — index, show, or sideloaded in `included` by some other endpoint — with zero per-endpoint wiring. **New client:** empty gap, document untouched, no walk performed.

### Trace B — query params up (sparse fieldsets)

**Old client:** `GET /data-explorer/api/queries?fields[queries]=name,sql` (header `2026-05-20`).

Without an up-rewrite, this fails *silently*: `jsonapi_fields` hands `["name", "sql"]` to the serializer, which knows no `sql` attribute → the field just doesn't match → response contains only `name`. No 400 (`reject_unknown_query_params!` checks filter/sort/include, not fields), no error — the client is quietly missing data it asked for. Then `down` has nothing to rename. Silent and wrong.

With the pipeline: the **first** before_action resolves the version and up-migrates the request — including the query-param surface. `fields[queries]` is type-keyed, so the `queries` up-context rewrites `sql` → `query`. The serializer then emits `query`, and Trace A's down renames it back. The client gets exactly `name` + `sql`.

**Gotcha found while building ② (TDD):** a naive delete-based rename transform *fabricates* the old
attribute as `null` when the new one is absent — exactly what happens when a fieldset excluded it
(`attributes[:sql] = attributes.delete(:query)` with no `query` present). Block transforms must be
**key-guarded** (`if attributes.key?(:query)`); the machinery can't guard this generically because it
can't know which keys a block touches. One more argument for the declarative tier (§3), which could be
fieldset-aware centrally.

Ordering constraint this fixes in stone: **version-resolve + up runs before `reject_unknown_query_params!` and before anything reads `params`.** (Had the renamed attribute been a declared sort/filter key, the same param rewrite applies; `queries` sorts are `name`/`last_run_at`/`username` today, so fieldsets are the realistic surface.)

### Trace C — request up (POST create)

**Old client:** `POST /data-explorer/api/queries` (header `2026-05-20`) with the *old* body:

```jsonc
{ "data": { "type": "queries",
            "attributes": { "name": "Slow topics", "sql": "SELECT ..." } } }
```

```
resolve → snap 2026-05-01 → gap = [rename]
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

Two things to notice: the create response flows through the same down pipeline as any read (one seam, `render_resource`), and `up` runs **before** deserialization. With the `only:` allowlist gone this ordering is a choice, not a necessity (the flat hash would carry `sql` through) — we keep it because transforms speak the **wire shape**: symmetric with `down` (one `VersionChange`, one shape for both directions), self-routed by `data.type` (which deserialization strips), and decoupled from the deserializer's flattening conventions (`relationships.groups` → `group_ids` — a relationship rename or attribute→relationship shape change must be expressed on the wire format, not on its flattened residue). *(Historical footnote: under the old `only:` allowlist, up-first was mandatory — the old client's `sql` would have been silently dropped before the service saw it.)*

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

### Trace F — nested types across a multi-change gap (added 2026-07-09, all green)

A second real change — `ChangeUsersUsernameToList` (`2026-07-01`): the **included** `users` type's
`username` (string) becomes `usernames` (array), modeled on Cadwyn's `ChangeAddressToList`, with a
deliberately lossy down (`.first`). Proven end-to-end on `GET /queries?include=user`:

| Client pinned | `queries` attrs | included `users` attrs |
|---|---|---|
| `2026-05-20` (before both) | `sql` | `username` |
| `2026-06-20` (between) | `query` | `username` — **per-change granularity** |
| `2026-07-01` (current) | `query` | `usernames` |

Also green: an old client's `fields[users]=username` on the included type, and the deep `user.groups`
include keeping full linkage while downgrading the user. The "applies wherever the type appears" claim
is now demonstrated, not asserted.

### Stress-test findings — data-manipulating transforms vs the synthetic trick (2026-07-09)

**Question (loic):** does the synthetic-resource trick (fieldsets-up, pointers-down) survive transforms
that manipulate *values*, not just keys? **Answer: real documents yes, synthetics no — now degraded
gracefully instead of crashing.**

- **Real documents: fully works.** Shape changes ride the pipeline like renames — the trust boundary
  holds because the serializer guarantees real values on the down path (the lossy `.first` is safe).
- **Synthetics carry `nil` values, violating that same trust boundary.** Confirmed live: a correct,
  key-guarded, value-touching down (`attributes.delete(:things).first`) raises `NoMethodError` on the
  synthetic. Two hazard classes: (1) value-*touching* transforms with fixed key maps → crash on nil;
  (2) value-*dependent* key maps (split/merge) → the synthetic can't drive the mapping at all.
- **Machinery fix (spike):** both synthetic paths (`up_fieldset`, `downgrade_attribute_name` — now
  co-located in `VersionPipeline`) rescue and fall back to the unchanged names. Degradation, confined
  to fieldsets/pointers naming a shape-changed attribute: the old client sees the *latest* name (pointer)
  or the field silently drops (fieldset). Never a 500.
- **Implication:** this is the forcing argument for the **declarative tier** — statically-declared key
  maps need no value code and no synthetics, making these two surfaces exact instead of best-effort.
  The declarative tier now has three motivations: four-surface duplication, type renames
  (document-global), and synthetic soundness for shape changes.

**Superseded (2026-07-09, same day):** the declarative tier below was built; both synthetic paths and
the rescue-fallback machinery are GONE, replaced by exact lookups over declared renames.

### The declarative tier (built 2026-07-09)

The core keyword — `renamed_attribute from:, to:, up:, down:, old_type:` (the last added
2026-07-23: a shape-changing rename declares its pre-rename wire type, consumed by the
versioned docs generator so old-version schemas and down-converted examples agree) —
states the **key-level fact as data**,
with optional **pure value→value converters** for shape changes:

```ruby
resource :users do
  renamed_attribute from: :username,
                    to: :usernames,
                    up: ->(username) { [username] },
                    down: ->(usernames) { usernames.first }
end
```

Both real changes are now declarations; the 17-example acceptance suite stayed green through the rewrite
(the equivalence proof). Rules:

1. **Key facts are data.** Body transforms are generated (key-guarded by the machinery — authors no
   longer write `if attributes.key?` boilerplate); fieldsets and error pointers are **pure lookups**
   over the declared maps. Converters never run outside a real document, so the nil-synthetic hazard
   class is gone *by construction*, not by rescue.
2. **Blocks remain the escape hatch** (non-attribute reshapes, `document` scope) and always operate on
   the change's **latest vocabulary**: declared renames run first on up, last on down.
3. **A change that alters key names must declare them** (decided with loic, option (b)): block-only
   changes contribute no fieldset/pointer mapping — names pass through unchanged. The acceptance spec
   is the enforcement (forgetting to declare fails Trace B/D/F-style examples).

**Future keywords** (sketched; built when a real case lands):

```ruby
# Splits/merges — fieldsets map many→one automatically; the ambiguous pointer
# (one→many) defaults to the FIRST entry of `from:`, overridable with `pointer:`.
# NB: reordering `from:` would change wire behavior — the immutability rule
# (shipped changes are never edited) is what makes the positional default safe.
merged_attributes from: %i[first_name last_name],
                  to: :full_name,
                  up: ->(attributes) { attributes.values.compact.join(" ") },
                  down: ->(full_name) { split_into_first_and_last(full_name) }

# Type renames — document-global (resource objects, relationship identifiers,
# fields[TYPE] keys), declared at class level, not inside `resource`:
renamed_type from: :queries, to: :reports
```

### Trace G — sorts and filters across renames (built 2026-07-09, all green)

The parked sort/filter question is resolved by connecting the declared rename maps to the Kit DSL's
**derived/virtual distinction** (decided 2026-07-08, now built):

- `sort :name` / `sort :ran_at, column: :last_run_at` — **no block = attribute-derived**: orders by
  `column:` (default: the key) and **follows the attribute through version renames automatically**
  (same lookup as fieldsets, keyed to the endpoint's primary type).
- `sort :username do … end` / `filter :search do … end` — **block = virtual**: its own contract surface,
  passed to the rewrite as `except:` so it is never renamed by attribute changes, even on a name
  collision (the "two separate contract decisions" rule, enforced by declaration rather than inference).

Proven with a third real change — `RenameQueriesLastRunAtToRanAt` (`2026-07-08`), chosen because
`last_run_at` *is* a derived sort: the wire attribute and the sort key move together
(`sort :ran_at, column: :last_run_at` — the ORDER BY column stays), with **no extra declaration** in the
`VersionChange` (one `renamed_attribute` covers body, fieldsets, pointers, *and* the sort key). End-to-end:
an old client's `sort=-last_run_at` orders correctly and gets `last_run_at` back in attributes; a current
client uses `sort=-ran_at`; virtual `sort=username` passes through untouched. The
contract guard flagged **both** surfaces on shipping (`attribute removed: last_run_at`,
`sort removed: last_run_at`) — derived sorts are contract-visible and move with their attribute.

**Virtual renames (the filter half, built same session):** virtual keys never follow attribute renames —
renaming one takes its own declaration, and the keywords now exist:

```ruby
resource :queries do
  renamed_filter from: :search, to: :q
  renamed_sort from: :username, to: :"user.username"
end
```

Proven with real changes #4 and #5, both dated `2026-07-08` alongside the `ran_at` change — **three
changes sharing one release date**, applied in registration order (a release-train day in miniature):

- `RenameQueriesSearchFilterToQ`: `filter :search do … end` became `filter :q`; the guard fired
  (`filter removed: search`); an old client's `filter[search]=…` is rewritten to `q` and filters
  correctly — without the rewrite it would 400, so the acceptance example is load-bearing.
- `RenameQueriesUsernameSortToUserUsername`: the virtual join-sort adopted the JSON:API-recommended
  dotted spelling for relationship-based sort fields (`user.username`, matching our `include` path
  convention); guard fired (`sort removed: username`); old clients' `sort=username` rewrites through the
  keyword. NB the dotted name is **labeling, not capability**: the supported sort set stays explicitly
  declared per key (unsupported → 400, per spec) — no arbitrary relationship-path sorting is implied,
  which would be client-driven JOINs (the default-on posture we rejected). Bonus property proven in
  passing: cross-resource virtual sorts are structurally immune to related-type wire renames — this sort
  survived the users `username`→`usernames` change untouched (virtual pin + it orders by the *column*).

Per-change key resolution: **explicit `renamed_sort`/`renamed_filter` map → virtual pin →
attribute-rename map** (`VersionPipeline.up_sort_keys`/`up_filter_keys`; fieldsets keep the plain
attribute map).
Derived *filters* remain deliberately not a concept (a separate query-surface decision). Follow-up
hardening noted: a boot-time invariant that no-block sort names must be serializer attributes.

### Trace E — header mechanics

| Request header | Result |
|---|---|
| *(missing)* | `400` — body teaches: current version, how to send the header, docs link |
| `2026-05-20` | `200`, resolved `2026-05-01` (snap down), echoed back |
| `2026-07-01` | `200`, resolved `2026-06-15`, empty gap → zero-cost passthrough |
| `2026-04-01` (before first version) | `400` — unknown version |
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

**Build order (small increments):** ① components 1–3 (pure Ruby, spec'd in isolation) — **done 2026-07-08** → ② response-down pipeline + controller seam (Traces A, E green — all reads benefit) — **done 2026-07-08** → ③ request-up (B, C) — **done 2026-07-08** → ④ errors (D) — **done 2026-07-08. ALL TRACES GREEN (acceptance spec 12/12).**

**④ implementation notes:**
- The pointer-rewrite case became real by adding a length cap on `query` to the `Query::Create` contract
  (10k chars — defensible on its own merits for a SQL payload).
- `VersionPipeline.down_errors(document, type:, changes:)` — error documents are typeless, so the endpoint's
  primary type is supplied (from the DSL config's serializer `record_type`), then dispatch works like any
  other transform. Pointer rewriting **reuses the synthetic-resource trick in the down direction**: parse
  `/data/attributes/<name>`, run the type's down chain over a one-attribute synthetic resource, and the
  resulting key is the old name. Same `VersionChange`, third surface, still zero extra declaration.
- Only `source.pointer` is migrated (the machine contract). `detail` prose stays in latest terms — an old
  client's error reads "Query is too long…" with pointer `/data/attributes/sql`. Documented compromise.
- Errors whose pointer targets anything other than `/data/attributes/<name>` (relationships, document-level)
  pass through untouched; a transform that *splits* an attribute (1 name → N keys) leaves the pointer as-is
  rather than guessing.

**③ implementation notes:**
- `VersionPipeline.up` takes the same newest→oldest gap the registry produces and reverses it internally — call sites stay symmetric, no ordering footgun. Within one change, up runs document-then-resources (the exact inverse of down's resources-then-document).
- The resource walk only invokes a transform when `attributes` is a hash — request documents are hostile input (machinery guarantees shape; transforms stay clean).
- **Fieldset rewrite without a params DSL:** `fields[TYPE]` values are attribute names, so the controller builds a *synthetic resource* from the names (`{type:, attributes: {name: nil, sql: nil}}`), runs the type's normal up-chain over it, and keeps the resulting keys. The same `VersionChange` covers body and fieldsets with zero extra declaration.
- **Deferred from ③, DECIDED 2026-07-08, BUILT 2026-07-09 (see Trace G):** sort/filter-*key* renames. The synthetic-resource
  trick is sound for `fields` because the spec defines fieldset values as the resource's *field names* — the
  same namespace the transforms reshape. Sort keys are only *recommended* to match attributes (ours don't
  always: `sort :username` is a join) and `filter` semantics are fully server-defined (`filter :search` isn't
  an attribute) — so auto-applying attribute renames there would have encoded a guess.
  **Decision (Graphiti-inspired):** make the relationship a *declaration* — the DSL will distinguish
  **attribute-derived** sorts/filters (`sort :name` — renames follow the attribute automatically, same
  soundness as fieldsets, with a `column:` escape hatch for when wire name ≠ DB column, e.g.
  `sort :query, column: :sql`) from **virtual** ones (`sort :username do … end`, `filter :search` — their own
  contract surface; renaming one takes an explicit `renamed_sort`/`renamed_filter` declarative keyword).
  Unlike Graphiti we keep declarations **opt-in** (the spike hardening deliberately flipped Graphiti's
  filterable/sortable-by-default OFF — default-on makes every attribute an unindexed-sort/LIKE-scan surface).
  Build when a real rename touches a sort/filter; risk while parked is low — strict params give old clients a
  loud 400, unlike the silent fieldset drop that forced ③ to handle `fields`.

## 2b. Related Kit conformance work — cursor-pagination profile alignment (2026-07-09)

The spec reference doc surfaced that the Kit's keyset pagination (invented `page[cursor]` +
`meta.page.next_cursor`, no links) did not match the registered
[cursor-pagination profile](https://jsonapi.org/profiles/ethanresnick/cursor-pagination). Aligned:

- **Params:** `page[size]` / `page[after]` / `page[before]` (range requests rejected with the profile's
  typed error — the profile's explicit opt-out). Cursor mode is entered by cursor params or by requesting
  the profile in the `Accept` header; `page[number]` remains the plain offset path.
- **Links:** top-level `prev`/`next` always present (null when no such page — null-accuracy via one
  look-ahead row + one EXISTS check); an empty window still links back/forward at its own cursor so
  clients can always escape it.
- **Item cursors:** each resource carries `meta.page.cursor` (the profile's deep-linking mechanism).
- **Typed 400s:** `max-size-exceeded` (with `meta.page.maxSize`), `range-pagination-not-supported`,
  `unsupported-sort`, and untyped invalid-parameter errors — all with the profile's `links.type` URI
  (emitted as a single link per base-spec shape, not the profile example's array).
- **Content negotiation:** cursor-mode responses (and typed errors) carry
  `Content-Type: application/vnd.api+json;profile="…"` using the registry's canonical https form.
- **Engine: `Pagy::Keyset`** (reassessed 2026-07-10 — an earlier hand-rolled id-only engine was replaced
  after loic pointed at core PR #36065: future endpoints paginate *virtual resources* over composite,
  mixed-direction keysets built from CASE-expression columns, exactly what Pagy's predicate composition —
  union-of-intersections with a DB-optimizer hint, `tuple_comparison` fast path, adapter typecasting — was
  built for and exactly the SQL the Kit should not own). `CursorPaginator` is now a thin adapter layering
  the profile's needs on Pagy: reverse (`before`) windows via a direction-flipped keyset, null-accurate
  prev/next (Pagy's native look-ahead + one probe query), and per-item cursors minted by mirroring Pagy's
  own cutoff derivation (keyset values → JSON → B64 — item and page cursors are interchangeable). Cursors
  are validated against the request's keyset (wrong-shape cursor → invalid-parameter 400).

**Keyset-only (decided 2026-07-10, loic):** the new API ships with **no traditional offset pagination** —
`page[number]` (or any unknown `page` member) → 400. Consequences, all built:

- **Derived sorts now cursor-paginate** — the keyset is the requested derived sort(s) (or `default_sort`)
  plus an `id` tiebreak, composed by Pagy. The earlier "sorts → typed error" limitation is gone for
  derived keys (proven: a name-sorted cursor walk in the request specs).
- **Virtual (block) sorts get the typed `unsupported-sort` error** — a bespoke JOIN has no keyset columns.
  The designed future path is PR #36065's pattern (SELECT the expression as a virtual column behind a
  subquery, keyset over it); until then, virtual sorts are explicitly not paginatable, and the versioning
  rename still runs first (an old client's error names the key in the latest vocabulary — spec'd).
- **The nullable-keyset trap, demonstrated live — then solved by declaration (2026-07-10):** with
  keyset-only pagination the default order became `default_sort` (`last_run_at DESC`) — a nullable
  column, and NULL rows were unreachable past page one (`last_run_at < NULL` matches nothing; caught by
  a failing walk spec). Fix, in the Kit idiom (declare the fact, machinery derives the rest):

  ```ruby
  sort :ran_at, column: :last_run_at, nulls: :last
  ```

  The paginator prepends a `<column>_is_null` CASE helper (0/1 — JSON-native, no cursor typecasting) to
  the keyset and wraps the scope in a subquery aliased as the table (PR #36065's trick) so the helper is
  orderable, predicable and readable. Two subtleties this surfaced, both spec'd: (1) **stock Pagy's
  predicate equality (`=`) dead-ends on cursors minted from NULL-valued rows** — `NullSafeEngine` is a
  verbatim copy of `compose_predicate` (43.6.0) with `IS NOT DISTINCT FROM` (upstream candidate);
  (2) subquery wrapping drops `includes` — which prompted the question (loic) of whether the Kit needs
  explicit preloading at all, given **Goldiloader**. Answered empirically: a query-count spec pins the
  no-N+1 invariant (one batched `IN` load per association level on a deep `user.groups` include), and it
  stayed green with every explicit preload removed — the Kit now carries **no preloading machinery**
  (`included_preloads`/`preload_tree`/`Preloader` deleted, ~30 lines). Goldiloader is recorded as a
  Kit-assumed platform gem; without it, post-fetch `Associations::Preloader` would need to return.
  Proven end-to-end: `sort=-ran_at` walks
  through never-run (NULL) queries in the request specs. **The default listing is recently-run-first
  again**: `default_sort ran_at: :desc` resolves through the *sort-key vocabulary* — one resolution path
  for requested sorts and the default (column mapping, nulls-last, virtual rejection), proving the
  plumbing composes end to end (a bare listing cursor-walks through the NULL tail; spec'd with an order
  that differs from id-order so it can't pass accidentally). The general *virtual-sort* DSL
  (`expression:`/`joins:`) remains designed-not-built for the real implementation phase;
  blocks-wrapped-in-subqueries are the sketched escape hatch for the weird cases.
- `stats[total]=count` still works (one COUNT on request, merged into cursor-mode meta); `meta.page.total`
  (MAY) remains unemitted. **Dropped from the stated contract 2026-07-30:** `stats` is ours rather than the
  profile's, and it invites an unbounded `COUNT` per page (the profile's own answer for expensive counts is
  the optional `estimatedTotal.bestGuess`). Left in the spike code, not offered as API.

## 2c. Positional entry — the anchor (designed and spiked 2026-07-31)

Requirement identified in design review: enter an ordered list at an arbitrary position and page **both
ways** from there, without a filter clamping every page. Treated as required rather than optional — the
post stream and chat both need mid-list entry, and more generally **any list that exposes its position in a
URL needs it**. Permalinks imply positional entry.

**Why cursors alone can't do it.** `page[after]`/`page[before]` take opaque cursors, and by profile
contract a client cannot construct one — it can only replay a cursor it has already received. So "start at
post 4217", "from this date", "users beginning with M" is inexpressible today. The gap is the *entry
point*, not the navigation: once a position is held, our machinery already does everything asked
(bidirectional windows, per-item cursors, `EXISTS`-probed prev/next links).

### Prior art (verified from primary sources 2026-07-31)

| API | Shape | Note |
| --- | --- | --- |
| **Stripe** | `starting_after` / `ending_before` take **an existing object ID** ("a cursor… an object ID that defines your place in the list"), mutually exclusive | Their cursor *is* a domain identifier, so arbitrary entry is free and no anchor concept is needed |
| **Zulip** | `anchor` (message ID **or** `newest` / `oldest` / `first_unread` / `date`) + `num_before` + `num_after` + `include_anchor` (default true) | The canonical centred-window shape, from a product whose core case is permalinks into long streams |
| **Matrix** | opaque `from`/`to` + `dir=b\|f` for continuation, plus a separate `/rooms/{id}/context/{eventId}` endpoint for entry | Keeps token opacity, pays for it with a second endpoint duplicating the query surface |

Two families overall: *value-as-position* (Stripe et al., entry is inherent) and *opaque tokens plus a
separate entry affordance* (Matrix). The JSON:API profile mandates opaque, server-defined cursors, which is
exactly what creates our gap. **Chosen direction: an anchor parameter (Zulip's shape), not a context
endpoint** — it composes with the existing filters, sorts and fieldsets instead of duplicating them.

### Mechanics: an anchor resolves to a RECORD; the cursor is minted from the record

The load-bearing rule, and the answer to "how does one value become a multi-part keyset tuple" — it never
does. The value only bounds the leading sort column; the tuple comes from the row that bound finds:

```ruby
value    = ActiveModel::Type.lookup(definition[:type]).cast(raw_value)
column   = cfg.sorts[active_sort_key][:column] || active_sort_key
operator = active_direction == :desc ? "<=" : ">="        # follows the SORT, not the word "after"
record   = keyset_ordered_scope.where("#{column} #{operator} ?", value).first
paginator.cursor_for(record)                              # → [0, <row's value>, <row's id>]
```

Consequences, worked through on the spike's own nullable sort (`sort :ran_at, column: :last_run_at,
nulls: :last`, keyset `(last_run_at_is_null, last_run_at, id)`):

- **`>=`/`<=` follows the sort direction.** `default_sort ran_at: :desc` means "start at 2026-07-01" is
  `last_run_at <= '2026-07-01'`. Hardcoding the operator is the obvious bug here.
- **A missing anchor row is fine**: the bound lands on the next row in order, which is what a permalink to
  a deleted post should do rather than 404. Same mechanism serves values that are not rows at all
  (`page[anchor]=M` on a name sort).
- **The null group excludes itself for free.** `last_run_at <= X` is never true for NULL, so a date anchor
  cannot land among never-run rows — no explicit `is_null = 0` needed.
- **…which means value anchors cannot reach a null group at all**, since no value names NULL. Symbolic
  anchors are therefore *required*, not sugar — and they take the identical path (select a record, mint
  from it). Zulip's `first_unread` is the same discovery from the other end, and it maps directly onto how
  Discourse enters a topic today.
- **Anchoring only makes sense on the leading sort column** (the only one a single value can bound), and
  only on paginatable sorts (§2b) — the anchor is resolved in the *sort-key* vocabulary, so renames stay
  invisible to clients.

Declaration sketch, in the Kit idiom (declare the fact, machinery derives the rest):

```ruby
sort   :ran_at, column: :last_run_at, nulls: :last
anchor :ran_at, :datetime                      # value anchors, typed for validation + docs
anchor :never_run { |scope| scope.where(last_run_at: nil) }   # symbolic, server-computed
```

**Three forms, because there are three kinds of knowledge about a position** — and none collapses into
another:

| Form | Wire | The client knows… |
| --- | --- | --- |
| identity | `page[anchor][id]=42` | the row |
| value | `page[anchor][ran_at]=2026-07-01` | a value in the ordering |
| symbolic | `page[anchor]=first_unread` | nothing — only the server can compute it |

The symbolic form is the one that earns the block. `first_unread` is how Discourse enters a topic today: the
position depends on per-user read state, so the client cannot know the post id in advance — if it could, it
would not need to ask. Same for "jump to the never-run queries", where identity only helps if you already
hold an id from that group, which means paging to the end first. Consequence for the implementation: a
symbolic anchor's block must be `instance_exec`'d in the controller, like `base_scope`, filters and sorts,
so it can read guardian and `current_user`. That is also why it is a block rather than a typed value.

The type is not needed for the SQL (AR would cast) but earns its place twice: a garbage value becomes a
typed 400 instead of a cast error, and the parameter is documented.

### Wire shape and open decisions

```
GET /api/posts?filter[topic_id]=1234&sort=post_number
    &page[anchor]=4217&page[before_size]=5&page[after_size]=20
```

Response: the concatenated window, `links.prev`/`links.next` as ordinary opaque cursors from the existing
probes (so navigation reverts to the standard params immediately — the anchor is *only* the entry), and
`meta.page.anchor` echoing the resolved cursor, which matters given the "next row in order" fallback.

Parked decisions:

1. **`page[anchor]` + two counts (Zulip) versus a single `page[size]` split in half.** Permalinks want
   asymmetric context; Zulip's experience says you end up wanting both numbers. Two counts also make the
   centred nature explicit rather than a convention.
2. **`include_anchor`** — "around post 42" nearly always includes 42, "after 42" doesn't. Explicit flag
   beats an implicit rule.
3. **Profile conformance.** The registered profile defines no such member, so this is an extension: either
   document it as one, or publish our own profile URI. Adding a `page` member quietly would break our own
   strict-parameter rule (`page` accepts exactly `size`/`after`/`before` today).
4. **Two wire shapes for one parameter.** A symbolic anchor has no value — the key *is* the position — so
   `page[anchor][never_run]=1` reads badly and the natural form is the scalar `page[anchor]=never_run`
   (Zulip's shape: their `anchor` takes an id *or* a symbolic name). Proposed rule: scalar means "a declared
   symbolic anchor", keyed (`page[anchor][key]=value`) means "a value for this key". Cheap to parse, and it
   keeps the keyed form's disambiguation where it is actually needed.
4. **Cost.** A centred window is a position seek plus two windows (~3 index seeks) — no `OFFSET`, no
   counting. Acceptable, but it is 2–3 queries where a normal page is one.

### The unifying rule this exposed

The null-flag helper (§2b), the designed `expression:`/`joins:` sorts, and the anchor are all the same
mechanism: **a sort is paginatable if its ordering value can be projected as a stable per-row column** —
then the keyset comparison, the cursor minting and the anchor seek all work unchanged. Virtual sorts are
rejected today not because they join, but because the block is *opaque*: it applies an `ORDER BY` the
paginator cannot see, so there is no value to encode. Making the value declarative fixes all three at once:

```ruby
# opaque — pagination refuses it
sort("user.username") { |scope, dir| scope.joins(…).order(Arel.sql("users.username #{dir} NULLS LAST")) }

# declarative — keyset `(user_username_is_null, user_username, id)`, and anchorable
sort "user.username", joins: :user, value: "users.username", type: :string, nulls: :last
```

Boundaries worth keeping: **correctness is not performance** (a keyset over a joined column may not be
served by one index, and the subquery wrapping can block index use in the outer query — so declaring one
stays a deliberate act, not something sprinkled on every relationship), and **unstable orderings stay
unpaginatable by design** (`random()`, live-recomputed trending scores — the cursor would point at a
position that no longer exists, which is a semantic failure, not a mechanical one). Those keep earning the
profile's typed `unsupported-sort`.

### Spiked 2026-07-31 — what the code proved, and what it changed

Built: `anchor name, type` on the resource, `page[anchor][<key>]` on listings,
`CursorPaginator#anchor_cursor { … }`. 11 request examples plus 4 unit examples over a composed
virtual-column keyset.

**No `identity:` flag — the kind follows the key.** `id` is an identity anchor because that is what
identity *means* in JSON:API (a resource is `type` + `id`); every other key is a value anchor on the sort
it names. Rejected alternatives: inferring from the schema (primary or unique-indexed column) would need
AR introspection, which the design refuses for types — and the model is only reachable through
`base_scope` at request time anyway; inferring "not a declared sort ⇒ identity" silently turns a mistaken
`anchor :created_at` into an exact timestamp match instead of the teaching 400. Note foreign keys are
*not* identity anchors: many rows share one, so anchoring on a foreign key is filtering. An alternate-key
identity anchor (a slug, an external id) would need an explicit declaration again — no case for it yet.

**Design change the spike forced: identity anchoring is the GENERAL case, value anchoring the special
one.** Checked against the shape core PR #36065 uses for `/latest` (two projected `CASE` columns —
`sort_priority` for pinning and a coalesced `sort_date` — mixed directions, subquery-wrapped, keyset over
the virtual columns). Its *leading* keyset column is synthetic: no client can ever supply a value for a pin
flag. So the useful form is "start at this record" (`page[anchor][id]=…`), which works under **any**
ordering, while a value anchor bounds the leading sort column and therefore must name the active sort
(otherwise: typed 400). Identity anchoring also reaches groups no value can name — proven on the spike's
NULL tail, where `page[anchor][id]=<never-run query>` lands in the group a date anchor cannot address.

**Implementation trick that kept it small.** The anchor resolves to a record, then returns the cursor of
the row *preceding* it; feeding that back as `after:` yields a window starting at the anchor, leaving the
window, link and probe machinery completely untouched. Cost: the seek plus one 1-row reverse window. No
inclusive-comparison variant of the keyset predicate was needed.

**Bug found in existing pagination (not in the anchor).** Cursors encoded timestamps through
`Time#to_json`, which truncates to milliseconds, while Postgres stores microseconds — so a cursor minted
from a sub-millisecond timestamp compares as *earlier than its own row*: the row repeats, or its neighbour
is skipped. It surfaced because the composed keyset's `sort_date` is a `created_at` (microsecond-precise),
where every existing spec used whole-second fixtures. Fixed by encoding `Time`/`DateTime` keyset values as
`iso8601(6)`. Worth remembering as a class of bug: **keyset correctness depends on the cursor round-tripping
the ordering value exactly**, so any lossy encoding (timestamps, floats, collated strings) is a silent
paging fault.

### Centred windows — built 2026-08-03

`page[before_size]` / `page[after_size]` (Zulip's shape) plus `page[include_anchor]`, which settles parked
decisions 1, 2 and 4 by building them:

| Want | Params |
| --- | --- |
| around | `page[anchor][id]=42&page[before_size]=5&page[after_size]=20` |
| after (unchanged) | `page[anchor][id]=42&page[size]=20` |
| before | `page[anchor][id]=42&page[before_size]=20` |

So before/after/around need no separate parameter names — two counts, and omitting one gives the one-sided
cases. `include_anchor` defaults to true, since "around row 42" almost always wants 42 while "after 42"
does not.

Implementation: `around: { record:, before:, after:, include: }` on the paginator runs two ordinary
windows hugging the anchor and concatenates them, each side's own probe answering whether there is more
beyond it — so links stay accurate at the ends of a list (spec'd: anchoring the first row yields a null
`prev` and a live `next`). A zero-sized side is a probe rather than a query. The plain
`page[anchor]` + `page[size]` path was folded onto the same code path rather than kept beside it, and the
eleven pre-existing anchor examples stayed green, which is what proves the refactor behaviour-preserving.

Decisions this forced, both worth keeping: the max-page-size cap applies to **`before + after + 1`**, not
to each count (spec'd — 60 + 60 against a cap of 100 is one `max-size-exceeded` error), and the window
counts **require an anchor** (they mean nothing without a position, so they get a teaching 400).

Still not built: symbolic anchors (`first_unread`-style, which need the declaration form and the scalar
wire shape from parked decision 4), and emitting the anchor parameters into the generated documentation.

### Declarative SQL-backed sorts — built 2026-07-31

The unifying rule above is now code, which retires the "virtual sorts cannot be keyset-paginated"
limitation for everything except blocks:

```ruby
sort "user.username",
     joins: "LEFT JOIN users ON users.id = data_explorer_queries.user_id",
     value: "users.username",
     nulls: :last
```

`value:` makes a sort SQL-backed; the paginator projects it as `<sql> AS <key>` (the key derived from the
public sort name — `user.username` → `user_username`) behind the same subquery the NULL helpers use, and
then ordering, keyset predicates, cursor minting and anchoring all work on it unchanged. `joins:` supplies
whatever the SQL needs. The paginator's new options are `expressions:` and `joins:`, so a caller can also
pass a keyset built entirely from SQL without any resource declaration.

Generality checked against three shapes, all spec'd: a **joined column** (the spike's `user.username`,
which lost its hand-rolled block — it now paginates *and* anchors, and an old client's `username` still
renames onto it first); **computed expressions with mixed directions** (`CASE WHEN hidden THEN 0 ELSE 1
END` ascending plus a coalesced date descending — core PR #36065's `/latest` keyset, expressed as options
rather than bespoke query code, walked across pages with no repeats or skips); and a **nullable
expression** (`nulls: :last` on a coalesced date, reachable at the tail). The NULL helper is computed from
the key's SQL rather than its alias, because Postgres cannot reference an alias in the `SELECT` that
defines it.

`value:` and `joins:` also accept a **callable**, evaluated in the controller like filters, sorts and
`base_scope`, so the SQL may depend on the request. That was not optional: `/latest`'s pinning clause
(`lib/topic_query.rb`) is built per request from the category param, from whether there is a current user,
and it references a join alias — none of which a string fixed at declaration time can express. Spec'd with
the same shape in miniature: a leading `CASE` that depends on *who is asking* (`user_id = <current user>`)
composed with a nullable date key, paginated across pages and anchored into.

**Hand-rolled scopes keep working.** Discourse has a lot of SQL written by hand for speed, so the
paginator was tried against the shapes that produces, not only against tidy relations: a scope whose
`FROM` is raw SQL containing a `UNION ALL`, and a joined scope with `GROUP BY` + `HAVING` (including an
aggregate as a keyset expression). Both walk every row exactly once and anchor correctly — the subquery
wrapping composes with whatever is underneath. The honest limits: the scope must be an
`ActiveRecord::Relation` (a `find_by_sql` array has nothing to paginate — core PR #36065 hit this and had
to branch on `is_a?(ActiveRecord::Relation)`), the ordering value must be projectable *and stable across
requests* (a window function over the filtered set is projectable but not stable, so keyset semantics break
exactly as they do for `random()`), and the extra subquery level is a planner consideration rather than a
correctness one.

What is deliberately still rejected: **block sorts**, which remain the escape hatch for orderings that
cannot be projected as a stable per-row column, and which keep earning the profile's typed
`unsupported-sort` (spec'd with a throwaway block declaration, since the spike no longer ships one).

Two gaps the comparison exposed in that PR's keyset, both of which the declarative path closes: it carries
**no tiebreak** (`{sort_priority: :asc, sort_date: :desc}`), so rows sharing a `sort_date` have no defined
order and a cursor between them is ambiguous — ours always appends `id`, per the profile's total-order
requirement; and its `apply_pinning ? … : …` branch is unnecessary, since with nothing pinned the composed
expression degenerates to `bumped_at desc` on its own.

Consequence for `/latest`: if it migrates to the Kit, its pinning keyset is two sort declarations rather
than hand-rolled projections plus a pagy call. What that does *not* cover is the rest of that PR — the
offset fallback and the legacy `TopicList` link plumbing — which belong to the old serialization path.

> Related: endpoints declared `internal` (see [resource design](./resource-design.md) §9) carry
> no version obligation and no mandatory version header — there is nothing to pin.

## 3. Open questions (discovered, deliberately parked)

- **Non-representational breaking changes — per-kind direction sketched** (raised in design review,
  2026-07-13; all contract-visible — the guard fires on each — but not reproducible by a document
  transform). Per kind:
  - *Endpoint removal — designed via pin-gating (2026-07-16, from a design discussion); no Rails
    routing involvement. **BUILT 2026-07-23** with one refinement: removals target the
    endpoint in the **Rails route dialect** — `removed_endpoint controller:
    "…/queries", action: :show, replacement: { controller: "…/queries", action: :index }`
    — the exact pair `url_for` resolves (yielding the real replacement path for the
    teaching 404) and validates (unroutable pairs raise; the replacement hash IS
    `url_for`'s arguments). Trade-off, stated honestly: a controller *constant* would have
    made "implementation must stay while pins are owed service" a boot-time alarm; the
    string form validates at use instead — registration-time `url_for` validation can
    restore the early alarm later. Docs integration included: removed operations vanish
    from the latest document and stay, marked deprecated, in documents for earlier pins.
    Metering remains unbuilt.* Following Stripe, sunset shouldn't happen — pinned versions are supported
    effectively forever (Stripe reference §10: no documented force-retirement since 2011). Under
    no-sunset, the endpoint code must live forever anyway, so "removal" was never about the routing
    table — it's a fact about the *timeline*: which pins can see the endpoint. Routes never leave
    Rails; the gate is one comparison in the Kit right after version resolution. Two keywords of
    different natures:
    - `deprecate :destroy, link: "…"` — **resource config**: advisory and reversible, not a timeline
      event; warns every caller regardless of pin via the RFC 9745 `Deprecation` header +
      `Link rel="deprecation"`. **BUILT 2026-07-23** (`deprecate action, on:, link:` on the
      resource class; headers emitted by the base controller; `deprecated: true` in the
      generated docs).
    - `removed_endpoint :destroy` — **a dated `VersionChange` keyword**: an immutable timeline event,
      like any breaking change. Pins resolved before its date are served normally plus
      `Deprecation: @<removal-date>` (a past date — exactly what RFC 9745 anticipates) and the doc
      link; pins at/after it get a **404 with a teaching body** ("removed as of 2026-09-01; versions
      pinned earlier still serve it; replacement: X"). 404 rather than 410 because in the new pin's
      contract the endpoint simply doesn't exist — 410 would claim "gone for everyone", which is
      false. Never the `Sunset` header (RFC 8594): Sunset means "will stop responding", which for
      old-pinned clients is precisely what is promised never to happen.
    One honest asymmetry vs `removed_filter` (which carries its block into the change): the endpoint's
    implementation *stays in place* — an action is a subsystem (action + service + serializer wiring)
    that old pins need working forever; the change carries only the date and metadata. The grep-able
    invariant survives (the gate is machinery driven by a dated declaration, not a version conditional
    in app code), and the mechanism composes with plugin ownership for free (a removal change is owned
    like any change, resolved per owner — see the plugins design doc).
    The gate doubles as a **metering point**, which turns "the code lives forever" into an
    evidence-based lifecycle rather than an absolute: every request to a deprecated or removed endpoint
    passes through Kit machinery that can record usage (endpoint × resolved pin × API key). Three
    stages: `deprecate` measures *all* callers while the endpoint is fully alive (data for deciding
    whether to ship the removal at all); `removed_endpoint` measures the residual old-pinned
    population; when that residual reaches zero or a negligible, contactable handful, the
    implementation can be *actually deleted* — a business decision grounded in telemetry, not a
    scheduled sunset. The client-facing promise stays intact: nobody is cut off by a timeline, and
    deletion only happens when the data says (nearly) nobody is left to cut off. Honest caveat:
    "negligible" isn't zero — a yearly-cadence integration can look dead; deletion also downgrades the
    teaching 404 to a bare 404 for everyone. Both are inputs to that final decision, not reasons to
    avoid it.
  - *Default-sort change:* a `changed_default_sort from: {…}` keyword — pinned-older clients' unsorted
    requests get the old default applied. Both orderings stay computable from current code; near-
    representational.
  - *Filter removal:* the version change **carries** the removed block (`removed_filter :q do |scope, v| …
    end`) — old behavior lives on, encapsulated and version-gated inside the dated change (Stripe's
    "tightly encapsulate old behavior" principle); new clients get the strict 400. NB this deliberately
    relaxes the "transforms are pure document reshapes" rule for the *query-surface* migration class —
    scoped, dated, and grep-able, unlike conditionals in app code.
  None built. Context: the spike changed `default_sort` twice with no `VersionChange`, silently reordering
  bare listings for pinned clients — the incident that named this class.
- **Query-surface scoping: per-resource, by convention** (from the same review — the
  `/users` vs `/leaderboard` example). Position: the spec scopes *document vocabulary* by type and leaves
  *query capability* per-endpoint, so this is a design choice — and the coherent choice is per-resource,
  matching Graphiti and our type-keyed renames: **same primary type ⇒ same collection semantics ⇒ same
  query surface (and shared renames); different semantics ⇒ different type** (a leaderboard is
  `leaderboard-entries` with `include=user`, not "users with extra sorts"). Follow-up for the real
  implementation: move the query-surface declarations from the controller to a resource-level home so
  declarations and renames live at the same level; endpoint-specific *extensions* to a shared type are
  deliberately unsupported until a real case demands endpoint-scoped renames.

- ~~**Error-pipeline context**~~ — RESOLVED in ④: the endpoint's primary type (from the DSL config) suffices;
  no dedicated error scope needed in the DSL. Revisit only if an error ever concerns a non-primary type.
- ~~**Declarative shorthand**~~ — RESOLVED: `renamed_attribute` BUILT 2026-07-09 (see "The declarative
  tier"); `merged_attributes` / `renamed_type` sketched, built when a real case lands.
- **Contract-guard integration** — the schema guard should learn "breaking change detected → demand a `VersionChange` + version date" instead of just failing.
- **`fields[]` strictness** — unknown fieldset entries silently no-op today (pre-existing, versioning makes it visible). Separate decision.
- ~~**Plugins**~~ — RESOLVED (explored 2026-07-15/16): see the [plugins design doc](./plugins-design.md) — type ownership, relationship placement, the version timeline (core-clock + explicit overrides), and the query-surface extension (namespaced, additive-only).
