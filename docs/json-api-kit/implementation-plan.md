# JSON:API Kit — implementation plan

**Status:** working document for the production implementation (branch `loic/json-api-kit-core`,
started 2026-08-03). The spike lives on `loic/json-api-experiments` — proven behaviour, spike-shaped
code, and the reference docs that explain *why* each decision was made. This plan says how we get
from one to the other.

## The bar

This is the real thing, so the spike's licence to take shortcuts is withdrawn:

- **Generic, not "enough for our first endpoint".** Every case the JSON:API spec describes will exist
  eventually; the design must not foreclose one. Where we don't implement something yet, it is
  because of sequencing, and the shape has to leave room for it.
- **Concepts identified and encapsulated.** Small objects, each with one job, named after what it *is*
  in the domain. The spike's 623-line `BaseController` is the anti-pattern: it resolved versions,
  parsed six parameter families, filtered, sorted, paginated, deserialized, rendered and built errors.
  All of those are separate concepts.
- **Specs first, always.** Behaviour is pinned before it is written; the spike's acceptance specs are
  the checklist we port.
- **No stand-ins.** No `serializer_for` placeholder registry, no monkeypatch from a plugin, no
  hand-maintained endpoint maps.

## Settled

| Question | Decision |
| --- | --- |
| URL | `/api/...` (easy to change later) |
| Namespace | `JsonApiKit` — that's the name now |
| Home | `lib/json_api_kit/` — a self-contained layer, extractable to a gem if it ever needs to be |
| Resources | `app/resources/`, with an `ApplicationResource` in the app, mirroring the `ApplicationRecord`/`ApplicationController` convention |
| Controllers | `JsonApiKit::BaseController` in the lib; the app subclasses through its own base |
| First endpoint | Its own slice, after the framework core — the framework is driven by specs first |
| `from_resource` | Slice 4, with the writes |
| Developer guide | Later, once the shape is real |
| Comments in the code | Prose for now — they carry the reasoning while the design is still moving. A documentation format for the public surface (YARD or similar) is a later decision, once that surface settles |
| Agent skill | With the developer guide, or after it — see *The agent skill* |

## Slices

Each is independently reviewable and additive — nothing existing changes behaviour, and nothing is
routed until we route it.

1. **Framework core.** Declarations, request parsing, query building, pagination, document assembly,
   errors. Driven entirely by specs (see *Testing without an endpoint*). This is the "core of the
   framework with missing stuff" that merges first.
2. **First endpoint.** A real resource on `/api/...`, which turns the framework's unit-proven parts
   into an end-to-end path.
3. **Versioning.** Registry, `VersionChange`, gap resolution, up/down pipeline, header handling.
4. **Writes.** `POST`/`PATCH`, the service bridge, `422` with JSON Pointers, `from_resource`.
5. **Documentation generation.** OpenAPI document, committed artifacts, drift loop.
6. **Contract guard.** Committed descriptor, CI failure on incompatible change.
7. **API key scopes.** Derived per endpoint, plugged into the existing system.
8. **Publication.** `internal`, the route helper's prefix derivation.
9. **Plugin extension API.** Namespaced relationships, filters, own timelines.
10. **Endpoint lifecycle.** Deprecation, dated removal, usage metering.

## Object map for slice 1

Names are the point of this section: each of these is a concept the spike had, mostly tangled inside
the controller. Every one of them should be testable without a request.

**Declarations** (`app/resources`, `lib/json_api_kit/declarations/`)

- `Resource` — the base class; declarations only, no behaviour beyond recording them.
- `Attribute`, `Relationship`, `Filter`, `Sort`, `Anchor`, `PageLimits`, `IncludePaths` — one object
  per declared concept, each owning what it knows: an `Attribute` reads a value off a record, a
  `Filter` applies itself to a scope, a `Sort` says whether it is column-derived, SQL-backed or opaque
  and yields its keyset key, an `Anchor` selects a row.
- `ResourceRegistry` — type ⇄ resource, replacing the spike's stand-in.

**Request** (`lib/json_api_kit/request/`) — one object per reserved parameter family, each strict by
construction, so "unknown parameter → 400" is not a separate concern:

- `Request::Fields`, `Request::Include`, `Request::Filters`, `Request::Sort`, `Request::Page`,
  `Request::Version`, `Request::Document` (writes).
- Each returns a value object: `Fieldsets`, `IncludePaths`, `AppliedFilters`, `Keyset`, `PageRequest`,
  `VersionPin`, `WriteDocument`.

**Pagination** (`lib/json_api_kit/pagination/`)

- `Keyset` — an ordered set of `Keyset::Key`s: the order to compare against, and the projection that
  makes every one of its values readable as a column of the scope. Built (2026-08-03).
- `Keyset::Key` — one term of the order: name, direction, backing SQL, joins, nullability. It answers
  for its own value on both sides — read off a record, and produced by the database — which is what
  dissolves the spike's four parallel collections keyed by the same names. `Keyset::NullFlag` is a key
  like any other, so nothing else in the keyset knows about nullability. Built (2026-08-03).
- `Cursor` — value ⇄ opaque string, with shape validation. Owns the lesson that lossy encoding breaks
  keysets: timestamps at microsecond precision, normalised to UTC. Built (2026-08-03).
- `Predicate` — the comparison selecting the rows after a cursor's position in an order, and only
  that. Built (2026-08-04); the rules it encodes are below.
- `Predicate::Term` — a key bound to the cursor's value for it, contributing its own fragments of the
  comparison, with `Term::Null` as the case a null cursor value becomes. Built (2026-08-04).
- `Window` — one page of rows read along an order, and whether the order carries on past them.
  It reads one way only, so reading backwards is a window over the reversed keyset, and a window of
  no rows is the probe form that answers whether anything lies that way at all — which retires the
  spike's separate probe. Built (2026-08-04).
- `Paginator` — a page and the cursors either side of it, as `Paginator::Forwards` or
  `Paginator::Backwards`: which end a page is read from decides the direction, whether rows come
  back in presentation order, and which side the window answers for rather than probes. An empty
  page still points at the cursor it was read from, or a client that pages one step too far is
  stranded. Built (2026-08-04).
- `Anchor::Resolver` and `Anchor::Window` — positional entry, including the centred form.
- `Profile` — the cursor-pagination profile's names, error type URIs and content type in one place.

**Documents** (`lib/json_api_kit/documents/`)

- `Collection`, `Resource`, `Errors` — assembly, each aware only of its own shape.
- `IncludeTree` — the requested paths as a tree, where a path implies its prefixes (that *is* full
  linkage), and `Included` — the deduplicating collection of side-loaded resources.
- `Links`, `ItemMeta`.
- `Errors::*` — one object per typed error (unsupported sort, max size exceeded, invalid cursor,
  unknown parameter, range pagination), each knowing its status, title, type URI and source pointer.

**Endpoint** (`lib/json_api_kit/`)

- `Endpoint` — the controller's declarations (resource, services, publication, scope overrides),
  extracted so the controller carries no state of its own.
- `Endpoint::Index`, `Endpoint::Show` — orchestrate scope → filters → keyset → window → document.
- `BaseController` — thin: builds a request context, delegates, renders. If it grows past a screen,
  something above is missing.

## Testing without an endpoint

Slice 1 has no real endpoint by design, and that is a feature: it forces the framework to depend on
nothing in the app.

- **Unit specs per object.** Most are pure; the ones touching the database take a scope.
- **Framework request specs against a fixture endpoint** defined in spec support (a `Resource` over an
  existing model plus a controller), with routes drawn per example. `with_routing` is the intended
  mechanism — to be confirmed, as nothing in the repo uses it yet; the fallback is a test-only route
  file loaded in the test environment.
- **Ported acceptance specs as the checklist**: profile conformance, traces A–G (slice 3), plugin
  rules (slice 9), documentation drift (slice 5), scopes (slice 7), anchors and centred windows,
  publication (slice 8).

## Ported, rewritten, decided

- **Ported nearly as-is** (proven, and the knowledge is in the details): the keyset predicate work
  including the null-safe equality, cursor encoding, nulls-last projection, the version pipeline's key
  maps and gap ordering, the OpenAPI schema derivation.
- **Rewritten**: everything that lived in the controller, the config object (the resource *is* the
  config), the endpoint registry, the plugin registration surface (it belongs in core's plugin API,
  not monkeypatched from a plugin), and the whole rendering path — with the assembler ours, the
  serializer patch, the include-prefix expansion and the empty-relationship pruning all disappear
  rather than move.
- **Dropped**: `stats[total]=count` (not in the profile, unbounded count), the run-stats stand-in
  plugin, the endpoint map.

### Decided: we assemble the document ourselves

The spike rendered with **jsonapi-serializer 2.2.0** (feature-dead). Getting a compliant document out
of it took three owned workarounds, all of them for the same underlying reason — the gem decides
linkage from a flat, direct-match include list:

1. A **monkeypatch** of `get_included_records`: it builds each nested resource's hash with the
   *parent's* parsed include list, so with `lazy_load_data` a nested leaf's linkage disappears.
2. **Include-prefix expansion** before rendering (`user.groups` → `user`, `user.groups`), because a
   nested path leaves the intermediate relationship's linkage off the primary data otherwise.
3. A **post-render document walk** pruning empty relationship objects: with `lazy_load_data`, every
   declared-but-not-included relationship is emitted as `{}`, and a relationship object must carry at
   least one of `links`, `data`, `meta`. Without the walk, the flat case is invalid on every resource.

On top of that the gem emits no relationship `links` at all, which is what a client's relationship
mode reads, and which it will never gain.

The perf axis, which was the one argument for staying, does not hold either. A **headroom probe**
compared three assemblies of a byte-identical document (8 attributes, one to-one and one to-many
relationship, in-process, GC off during timing, plain objects so no attribute-read tax dilutes the
signal): the gem, a straight-line hardcoded assembler (the time floor), and a **declaration-driven
sketch of what we would own** — dot-path include trees with prefix implication, cross-tree dedup,
sparse fieldsets applied per type, nested recursion.

| records | include | gem | ours (sketch) | floor |
| --- | --- | --- | --- | --- |
| 50 | — | 0.163 ms / 912 allocs | 0.058 ms / 309 | 0.021 ms / 304 |
| 50 | `author,tags` | 0.521 ms / 2688 | 0.156 ms / 999 | 0.125 ms / 1214 |
| 50 | `author.groups` | 0.456 ms / 2066 | 0.102 ms / 597 | 0.057 ms / 649 |
| 1000 | — | 3.149 ms / 18012 | 1.148 ms / 6009 | 0.396 ms / 6004 |
| 1000 | `author,tags` | 9.878 ms / 51940 | 2.891 ms / 18099 | 2.378 ms / 23064 |
| 1000 | `author.groups` | 9.016 ms / 41212 | 1.928 ms / 11241 | 1.071 ms / 12622 |

A generic assembler is **2.7–4.7× faster than the gem and allocates ~3× less**, and the flat case —
where its per-attribute generality costs the most against the floor — is still 2.8× faster than the
gem. In per-request terms the win is small (sub-millisecond against a ~28 ms compound response), so
the point is not speed: **owning the assembler costs nothing in performance**, and the abstraction
budget for declarations, versioning transforms and links is already paid for.

So: **write it, and drop the dependency.** It also collapses two declaration systems into one — the
gem's class macros were a second model derived from the resource, which is exactly the kind of
stand-in this plan rules out.

What the sketch does not yet cover, and what specs therefore have to drive: relationship `links` and
meta, resource and top-level links and meta, polymorphic types, `fields` narrowing relationship keys,
null to-one linkage, cycles, and the identity rules (`id` always a string, type naming). The floor
figures are a *time* bound only — the sketch already allocates less than the floor, whose dedup keys
were arrays where the sketch nests hashes.

### Decided: no pagination engine dependency

The spike ran its keyset windows through `Pagy::Keyset`, subclassed as `NullSafeEngine`. Pagy is not a
core dependency — it existed only in the spike's Gemfile — so the question was never "drop it", it was
"add it". The answer is no.

What was left of it once `Keyset` and `Cursor` became ours: the `limit + 1`-and-pop fetch, which is
`Window`'s job anyway, and one line of typecasting that is wrong for projected keys (an expression
alias has no attribute type). Everything else we had already replaced — order extraction, cursor
encoding, identifier quoting — or overridden: the predicate composer was a verbatim copy of a
`protected` method with `=` changed to `IS NOT DISTINCT FROM`, held together by an `allocate`
constructor bypass, and fed a `keyset:` option duplicating our own `Keyset`.

Owning it also produces better SQL, because the engine cannot know what we know:

- **`IS NOT DISTINCT FROM` is not an indexable condition.** On PostgreSQL 15.18 with `enable_seqscan`
  off, `id = 5` plans as `Index Cond`, while `id IS NOT DISTINCT FROM 5` plans as a post-scan
  `Filter`; `deleted_at IS NULL` is an index condition again. Knowing per key whether the cursor value
  is null, we emit `col IS NULL` or `col = :value`, both indexable, for the same correctness.
  **Measured (2026-08-04, 500k rows, matching index, cursor at row 400k): the three shapes are
  indistinguishable — 0.010 ms each.** The leading-key bound is what positions the index scan, so the
  equality terms are only ever a post-filter within one tie group, whichever operator they use. Row-wise
  remains the better shape (the whole predicate becomes the `Index Cond`, nothing is filtered) but an
  earlier claim here that null-safe equality "degrades every equality term on every page" was wrong.
- **Row-wise comparison is unsafe with nullable keys.** `(a, b, c) > (:a, :b, :c)` is the friendliest
  form for an index, and it evaluates to NULL — silently dropping rows — if any element is NULL. An
  engine with no concept of nulls cannot guard that; a keyset that knows which keys are nullable can
  apply the optimisation exactly when it holds.

So the `Paginator` owns predicate composition (OR-of-ANDs, the leading-key `>=` hint for optimizers
that struggle with ORs, row-wise comparison when every direction agrees and no key is nullable), typed
binding (cast by column type for column keys, pass through for projected ones) and the fetch. Under
specs, which the copied predicate never had.

Caveat to re-check on real data when `Paginator` lands: the plans above come from a 68-row table, so
the *costs* are meaningless — it is the `Index Cond` versus `Filter` structure that generalises, and
none of it bites unless the keyset's leading columns have a supporting index in the first place.

#### What the predicate emits

Built 2026-08-04. It means one thing — the rows after this cursor's position in this order — because
reading backwards reverses the keyset rather than inverting the comparison, leaving one shape to get
right instead of two. Cursor values arrive from a client and are always bound; the only literal text is
what a resource authored, a key's name and its SQL.

| case | shape |
| --- | --- |
| directions differ | a bound on the leading key, then the OR-of-ANDs |
| every direction agrees, no null values | row-wise `(a, b) > (:a, :b)` |
| a key's cursor value is null | `col IS NULL` where it must match, and no strict disjunct for it |
| the *leading* cursor value is null | no bound on the leading key |

The last two are traps, not optimisations:

- **The leading-key bound has to go when its cursor value is null.** It is ANDed with the disjuncts, so
  `col >= NULL` is NULL and the whole predicate then matches nothing — a silently empty page. Only
  reachable for a nullable key declared without `nulls_last`, which is precisely the case nobody tests.
- **A key whose cursor value is null gets no strict disjunct.** Inside a group of NULLs nothing sorts
  after NULL, so that disjunct could never hold and only bloats the plan.

Row-wise comparison is automatic rather than an option (Pagy's `tuple_comparison`), because the keyset
can prove when it holds. That hands the declaration layer a decision: the fast form only applies when
the tiebreak sorts the same way as the leading key, so `sort=-created_at` earns it with an `id: :desc`
tiebreak and loses it with `id: :asc`. **Open, for `Sort`: should a tiebreak follow the leading key's
direction?**

Two smaller findings worth not rediscovering. The predicate compares against the *projected* columns,
never the SQL behind them — the wrapping relation no longer exposes `users.username`, only
`"topics"."author"` — which is why a key answers both `identifier` and `value_sql`. And
`type_for_attribute` returns a passthrough `ActiveModel::Type::Value` for a name it does not know, so
turning a cursor value back into its column type is one uniform call on the key, with no branch for
projected ones.

How it is put together: a `Predicate` holds one `Term` per key — the key bound to the cursor's value for
it — and each term contributes its own fragments (the disjunct where it moved past the cursor, the bound
it puts on the whole comparison, its binding). A cursor value that is null becomes a `Term::Null`
instead, which matches by testing for null, contributes no disjunct, bounds nothing and binds nothing.
So the four rules above are answered by the special case itself rather than by four questions asked
about it, and the only place nil is read is the boundary where a term is built. The predicate's own
methods are then pure composition: which form, which disjuncts, which bound.

### Open: a nulls-last order wastes its index bound, and segmenting is the fix

Measured 2026-08-04 on 500k rows, page size 50, an index for every shape, each variant checked by
comparing the rows it returns rather than how many. Cursor at depth 400k in the valued part of a
`pinned_at desc nulls last, id` order:

| shape | time | plan |
| --- | --- | --- |
| what we emit today (flag leads the order) | 8.2 ms | Index Scan, no index condition |
| tail removed, OR-of-ANDs, no bound on the leading key | 5.4 ms | Index Scan, no index condition |
| tail removed, OR-of-ANDs, **bound on the leading key** | **0.011 ms** | `Index Cond: pinned_at <= …` |
| tail removed, uniform directions, row-wise | 0.009 ms | `Index Cond: ROW(…) < ROW(…)` |
| a plain keyset at the same depth, either shape | 0.007–0.009 ms | `Index Cond` |

**The leading-key bound is what makes a keyset predicate seekable.** Not row-wise, which is worth about
1.5× on top of it, and not direction uniformity, which on its own changed nothing. We already emit the
bound — the fault is *which key it lands on*: a nulls-last key puts its 0/1 flag at the head of the
order, and `flag >= 0` is true of every row in the table, so the seek is spent on nothing.

Nor can the bound simply be moved to the nullable column while the tail stays in the query: `NULL <= P`
is NULL, so bounding `pinned_at` would drop the tail. Taking the tail out of the query is precisely what
lets the bound land on a selective column — which is the fix, and all of it:

1. **Segment the order** at a nullable key: valued rows, then the null tail. The cursor already says
   which segment it names, since a null value for that key *is* the marker — no flag needed to tell them
   apart.
2. The bound then lands on the nullable column, and the page seeks: **8.2 ms → 0.011 ms**.
3. The tail reads as `col IS NULL AND id > :id`, measured at 0.037 ms, needing none of this.
4. `ORDER BY col DESC NULLS LAST` replaces the projected `CASE`, so nulls-last keys stop needing a
   projection or an expression index — the index does have to match the declared order.
5. *Optional polish:* inside the valued segment there are no NULLs, so row-wise becomes legal there, and
   with a tiebreak that follows the leading key's direction it applies. Worth ~1.5×. This is the answer
   to the tiebreak question left open above — worth having, not worth forcing.

It generalises past nulls, which is the case that actually matters. A listing that puts a group first —
pinned topics, then everything else by its ordinary order — has the same structure: a computed priority
column leads the keyset, and the bound is spent on it. Measured on the same 500k rows, group = a business
predicate over three columns matching 18,182 rows, order `created_at desc, id desc`, cursor deep in the
second group:

| shape | time | rows |
| --- | --- | --- |
| priority column leads the order | 10.0 ms | identical |
| segmented, bound on `created_at` | **0.010 ms** | identical |
| segmented, row-wise | 0.009 ms | identical |

Every variant returns the same rows, at depth and on the first page: **segmenting reorganises the query,
never the sequence** — the segments concatenated in order are what a single `ORDER BY` produces. Two
further findings from that run: the group predicate needs **no index of its own** (with only
`(created_at DESC, id DESC)` present the page still ran in 0.012 ms, the bound seeking and the predicate
filtering two rows out), so per-user conditions such as dismissals or `pinned_until > now()` are free; and
the first page gets marginally *slower* (0.011 → 0.092 ms, both negligible) because it reads the leading
segment and then spills into the next.

So the concept to build is not "nulls-last handling" but a **segmented order**: an ordered list of
segment predicates, each paired with the keyset that orders it, where the cursor names its segment. A
plain order is one segment; a nullable key is two; a listing with a pinned group is two with the group
predicate supplied by the resource. That also retires the projected priority column such listings build
by hand today.

What it costs: `NullFlag` stops being a key, `Keyset#order` learns `NULLS LAST`, `Predicate` becomes
segment-aware, and `Window` has to spill from a short valued page into the tail. Sequenced — today's
machinery is correct, this is about depth. The benchmark lives outside the repo; its seed rebuilds in
under a second.

> Three revisions of this section in one session, each because a measurement contradicted the previous
> reading: first that null-safe equality degraded every page (it does not, the bound rescues it), then
> that the `OR … IS NULL` term was the cost (it is not, the wasted bound is), then that row-wise was the
> fix (it is polish). Verify by comparing returned rows, not row counts — two of the three wrong readings
> came from a variant that was quietly answering a different question.

## The agent skill

`.skills/discourse-json-api-kit-authoring/SKILL.md`, following the convention in `.skills/`
(frontmatter `name` + `description`, one directory per skill). Written with the developer guide or
just after it, since both derive from the same material.

It **points at the developer guide as its source of truth rather than restating the rules** — for the
same reason the API documentation is generated: two hand-written descriptions of one set of rules
drift, and the one an agent reads is the one nobody notices has gone stale. What the skill adds on top
is the part a guide written for humans can leave implicit, because a human infers it from the
surrounding code and an agent does not:

- Which declarations exist, and where an endpoint's files go — a resource in `app/resources`, a
  controller through the app's own base, routes through the route helper. Never a hand-maintained map.
- A change to a resource's shape that a client could notice is a `VersionChange`, never an edit in
  place. The contract guard failing means a version change is missing, not that the baseline needs
  updating.
- Committed artifacts (the OpenAPI document, the contract descriptor) are regenerated, never edited.
- A sort is paginatable only if its ordering value can be projected as a stable per-row column; a
  block sort cannot be paged.
- `internal!` is the opt-out from documentation and versioning, and what that costs the endpoint (no
  API key scope, no support promise) — so it is a deliberate choice, not a shortcut around writing a
  version change.
- The vocabulary: "plugin" for Discourse plugins throughout, since "extension" is reserved by the
  spec's own `ext` mechanism.

## Definition of done, per slice

- Specs green, lint clean, no TODOs left in the code.
- Every JSON:API area the slice touches is either covered or explicitly listed as sequenced-not-built,
  in this document.
- Reference material updated when a decision changes — the durable artifact is the design, not the
  code.
