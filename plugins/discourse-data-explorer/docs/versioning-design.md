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

**Old client:** `GET /data-explorer/api/queries` with `Discourse-Api-Version: 2026-05-20`.

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
render json: document          + echo header: Discourse-Api-Version: 2026-05-01
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

The core keyword — `renamed_attribute from:, to:, up:, down:` — states the **key-level fact as data**,
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
  renamed_filter from: :search, to: :q    # renamed_sort works identically
end
```

Proven with a fourth real change — `RenameQueriesSearchFilterToQ` (`2026-07-08`, deliberately the **same
date** as the `ran_at` change: two changes sharing a release date, applied in registration order — a
release-train day in miniature). The config's `filter :search do … end` became `filter :q`; the guard
fired (`filter removed: search`); an old client's `filter[search]=…` is rewritten to `q` and filters
correctly — without the rewrite it would 400, so the acceptance example is load-bearing. Per-change key
resolution: **explicit `renamed_sort`/`renamed_filter` map → virtual pin → attribute-rename map**
(`VersionPipeline.up_sort_keys`/`up_filter_keys`; fieldsets keep the plain attribute map).
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

## 3. Open questions (discovered, deliberately parked)

- ~~**Error-pipeline context**~~ — RESOLVED in ④: the endpoint's primary type (from the DSL config) suffices;
  no dedicated error scope needed in the DSL. Revisit only if an error ever concerns a non-primary type.
- ~~**Declarative shorthand**~~ — RESOLVED: `renamed_attribute` BUILT 2026-07-09 (see "The declarative
  tier"); `merged_attributes` / `renamed_type` sketched, built when a real case lands.
- **Contract-guard integration** — the schema guard should learn "breaking change detected → demand a `VersionChange` + version date" instead of just failing.
- **`fields[]` strictness** — unknown fieldset entries silently no-op today (pre-existing, versioning makes it visible). Separate decision.
- **Plugins** — namespaced-key convention + who owns the timeline (shared vs per-plugin): scheduled for its own exploration (see topic 186394 discussion).
