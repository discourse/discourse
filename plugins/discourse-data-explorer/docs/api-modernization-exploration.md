# API Modernization Exploration

**Status:** Exploratory / RFC — Graphiti spike in progress (see Part 8)
**Last updated:** 2026-06-11
**Scope:** Contained in the `discourse-data-explorer` plugin. Core touches are limited to
two lines: the `graphiti`/`graphiti-rails` entries in the root `Gemfile`, and a
`Group.has_many :query_groups` association patch in `plugin.rb` (needed by the `groups`
sideload).

## Why this document exists

We want to explore options to **modernize and unify how we write APIs in Discourse**,
backend-wise. The frontend is experimenting with **WarpDrive** (the evolution of
EmberData), whose cache is normalized around the **JSON:API** standard, so it makes
sense to lean toward JSON:API-capable backends.

The ambition is bigger than "make WarpDrive happy": we're looking for something we
could stand behind as *"this is now the way we write APIs in Discourse"* for the next
**5–10 years**. That means a **public** API with **proper contracts, constraints, and
versioning** — not just a serializer swap.

We're using the **data-explorer plugin as the testbed**, starting with the `Query`
resource.

### Goals

- A clean, **public** API with stable contracts.
- **Full embrace** of the JSON:API spec (not just the document shape — the query
  surface too: `include`, sparse fieldsets, `filter`, `sort`, `page`).
- A **versioning** strategy that can last a decade.
- Pairs naturally with **WarpDrive** on the frontend.
- A choice we can **standardize on** and **maintain** long-term.

### Non-goals (for now)

- Touching Discourse core.
- Shipping anything to production.
- Migrating the existing data-explorer endpoints wholesale.

---

## Part 1 — The data-explorer surface (testbed map)

Data Explorer is, at heart, **one real entity (the saved SQL query) plus a transient
computation (its result)**. Everything else is access control and presentation around
those two.

### Core concepts

- **Query** (`data_explorer_queries`) — a saved SQL string with `name`, `description`,
  `sql`, `user_id`, `last_run_at`, `hidden`. Two things are *derived, not stored*:
  - **`params`** — parsed out of the SQL itself. A `-- [params]` comment block declares
    typed parameters (`-- foo :integer = 5`), parsed by `Parameter.create_from_sql`
    into `Parameter` objects (16 types: scalars, entity-id types like
    `user_id`/`topic_id`, list types, plus a server-injected `current_user_id`).
    `param_info` in the API is computed from `sql` on every request — there is no
    params table.
  - **Default queries** — a library of built-in queries
    (`lib/discourse_data_explorer/queries.rb`) with **negative IDs**. They are virtual:
    not in the DB until someone edits one. `Query.find` is overridden so negative IDs
    resolve from the hash (`QueryFinder`), and the index merges these "unpersisted
    defaults" into the listing. **This is the single quirkiest thing in the plugin and
    it will fight any framework that assumes stable, DB-backed, positive IDs.**

- **QueryGroup** (`data_explorer_query_groups`) — join between `Query` and `Group`. Its
  only job is access: members of a linked group can run that query via group "reports".
  It is also `bookmarkable` (you bookmark a query-in-a-group, not a bare query).

- **Result** — **not persisted, not a record.** Running a query opens a read-only,
  statement-timeout'd transaction, runs the SQL wrapped in
  `WITH query AS (...) SELECT * FROM query LIMIT n`, rolls back, and returns a hash:
  `columns`, `rows` (array-of-arrays), `duration`, `result_count`, `params`, optional
  `explain` — plus two interesting fields:
  - **`relations`** — when a column is named `user_id`, `topic_id`, `post$user`, etc.,
    the runner plucks those records and serializes them (BasicUserSerializer,
    SmallPostWithExcerptSerializer, …), keyed by type.
  - **`colrender`** — a `column-index → type` map telling the frontend to render that
    column as a user card, post excerpt, badge, reltime, json, url, etc.

  > **Key insight:** that `relations` + `colrender` pair is a **hand-rolled compound
  > document** — exactly what JSON:API formalizes as `included` + relationship linkage,
  > and exactly what WarpDrive's cache wants natively. "Run a query" is therefore the
  > highest-signal thing to model in JSON:API; CRUD on `Query` is the easy part.

- **Supporting pieces:** `schema` (full DB structure dump for the SQL editor's
  autocomplete, ETag-cached), CSV/JSON result **downloads**, **AI generation** (async,
  DiscourseAi-gated, returns a `generation_id` to poll), result **caching**
  (`QueryResultCache`), and integrations (automation recurring reports, admin-dashboard
  report provider).

### API surface

All actions live in a single **`QueryController`** (~370 lines), mounted at
`/admin/plugins/discourse-data-explorer` (engine) with extra top-level routes for group
reports and the public API.

| Endpoint | Action | Returns | Serializer |
|---|---|---|---|
| `GET queries` | `index` | query list + `total_rows_queries` + `load_more_queries` | `QuerySerializer` |
| `GET queries/:id` | `show` | one query + `cached_result` | `QueryDetailsSerializer` |
| `POST queries` | `create` | created query | `QueryDetailsSerializer` |
| `PUT queries/:id` | `update` | updated query (+ group sync) | `QueryDetailsSerializer` |
| `DELETE queries/:id` | `destroy` | soft-delete (`hidden: true`) | — |
| `POST queries/:id/run` | `run` | **result** (json/csv/download) | — (raw hash) |
| `POST queries/preview` | `preview` | result for unsaved SQL | — |
| `POST queries/generate` | `generate_with_ai` | `{generation_id, status}` | — |
| `GET schema` | `schema` | DB schema metadata | — (raw hash) |
| `GET groups` | `groups` | `[{id, name}]` for picker | — |
| `GET /g/:group/reports[...]` | `group_reports_*` | group-scoped list/show/run | `QuerySerializer`, `QueryGroupSerializer` |
| `GET /data-explorer/queries/:id/run` | `public_run` | result (public GET API) | — |

**Serializers (all AMS):** `QuerySerializer` (id, name, description, **username**,
**group_ids**, last_run_at, user_id, is_default) → `QueryDetailsSerializer` adds (sql,
param_info, created_at, hidden). `QueryGroupSerializer` (id, group_id, query_id,
embedded bookmark hash). Plus `SmallBadgeSerializer` / `SmallPostWithExcerptSerializer`
for result relations.

**Auth:** admin-only by default; `skip_before_action :ensure_admin` for group-reports +
`public_run`, which instead use the plugin's Guardian extensions
(`user_can_access_query?`, `group_and_user_can_access_query?`). There is also an **API
key scope** (`run_queries`) for the run endpoints.

### Frontend data layer (matters for the WarpDrive swap)

It is **not raw ajax** — it already uses Discourse's REST abstraction:
`Query extends RestModel` + `buildPluginAdapter("discourse-data-explorer")`. The model
hand-rolls its client-side serialization (`updatePropertyNames`, `createProperties`,
`updateProperties`), treats `group_ids` as a flat array and `param_info` as an array of
hashes. So there is already a store/adapter/model layer here — **WarpDrive would be
replacing an existing abstraction, not introducing one to ajax soup.** Favorable
starting point.

### Architecture notes that affect the migration

- **Business logic lives in the controller**, not services: `index` does pagination +
  defaults-merging inline; `update` runs its own transaction and group-sync inline. Only
  `QueryCreator` is extracted — and it's a plain class, *not* a `Service::Base`. A clean
  API rebuild is a good chance to push this into the service framework.
- **AMS serializers** are simple and map almost 1:1 onto JSON:API serializers.
- The **negative-ID virtual-default-queries** pattern resists every standard assumption
  (stable IDs, persisted records, clean pagination). Decide early whether the experiment
  includes it or brackets it off.

---

## Part 2 — JSON:API readiness, resource by resource

| Concept | Fit | What it takes |
|---|---|---|
| **Query** | Clean | `type: "query"`. Today's flat `user_id`/`username`/`group_ids` become proper `user` (belongs-to) + `groups` (has-many) **relationships** with linkage + `included`. `param_info` stays a JSON attribute (or a sub-resource). |
| **QueryGroup** | Clean-ish | `type: "query-group"` relating query↔group; the embedded bookmark becomes its own resource or `included`. |
| **Group** | Already core | The `groups` picker endpoint is just a thin list. |
| **Result** | **The research question** | `relations`/`colrender` is *already* a compound document → maps to `included` + relationship linkage. But `rows` (array-of-arrays) + `columns` is **tabular, not resource-shaped** — JSON:API has no table primitive. Pragmatic path: a singular `query-result` resource with rows/columns/duration as attributes and the typed entities as `included`. This is the case that tests whether JSON:API earns its keep for computed, non-CRUD payloads. |
| **Index pagination/sort/filter** | Reshape | Bespoke today (`offset`, `load_more_queries`, `total_rows_queries`, `order`/`ascending`/`filter`). Maps onto standard `page`/`sort`/`filter` + `links.next`/`meta.total` — but the **defaults-merging** (negative-ID virtual rows mixed into a paginated DB list) is awkward in any framework. |
| **schema / AI generate / CSV download / explain** | Leave alone | Static metadata, async RPC-style actions, and binary downloads — none are CRUD resources; keep as custom endpoints. |

---

## Part 3 — Backend framework options

### Maintenance reality check (the crux for a 10-year bet)

| Project | Latest release | Rails 8? | Read |
|---|---|---|---|
| **jsonapi-resources (JR)** | 0.10.7 (2022) | No | **Effectively dormant** |
| **Graphiti** | 1.10.2 (Mar 2026) | Yes (8.1 since 1.9.0) | Genuinely active |
| **jsonapi.rb** | 2.1.1 (Jun 2024) | (thin, version-agnostic) | Quiet but stable; little surface to break |
| **Grape** | 3.2.1 (Apr 2026), 83M downloads | Yes | Very active — *but the JSON:API adapter is a separate, much smaller project* |

The single most important data point: **jsonapi-resources was *the* batteries-included
JSON:API framework for Rails, and it is now ~4 years without a meaningful release and no
Rails 8 support.** That is exactly the failure mode we're trying to avoid for a
decade-long standard — and it already happened to the most popular option in this space.

### Decision matrix (weighted for *public* + *full JSON:API embrace*)

JR is dropped (dead). Grape's JSON:API support is an **output formatter only** — it
gives the document shape but none of the query surface, so it cannot "fully embrace" the
spec without re-implementing `include`/`fields`/`filter`/`sort`/`page` by hand.

| Criterion | **jsonapi.rb (thin-layers)** | **Graphiti** | **Grape + grape-jsonapi** |
|---|---|---|---|
| **Full JSON:API query surface** | ✅ all, explicit opt-in wiring per controller | ✅✅ all natively + deep sideloading, least code | ❌ formatter only — you build the surface |
| **Public contract + OpenAPI docs** | ⚠️ DIY (rswag from request specs) | ⚠️ own `schema.json` (not OpenAPI) — **but** auto backwards-compat CI guard | ✅✅ grape-swagger (mature) |
| **Versioning** | DIY in Rails (easy) | DIY in Rails (easy) | ✅ first-class |
| **Longevity / low lock-in** | ✅✅ thin, forkable, swap the serializer | ⚠️ healthy now, but bus-factor + high lock-in | ✅ framework solid / ⚠️ adapter fragile |
| **Discourse-fit** (Guardian, `Service::Base`, ActionController) | ✅✅ all reused as-is | ⚠️ auth is 100% DIY (base_scope + guards); `save` can delegate to a service, but side-posting fights it | ❌ reconstruct auth/`current_user` outside AC |
| **Verdict** | **Best for the decade commitment** | **Best to *experience* full JSON:API fast (spike)** | Weakest for *this* goal |

### The strategic read

1. **No single tool is strong on both halves of the requirement.** The JSON:API-native
   options (Graphiti, jsonapi.rb) are strong on format/query semantics but give you no
   versioning or OpenAPI docs out of the box. Grape is strong on versioning, param
   contracts, and OpenAPI docs but its JSON:API support is shallow and it costs you
   ActionController (Guardian, `current_user`, services, CSRF, rate limiting).

2. **For a decade bet, a heavyweight all-owning framework is a liability, not an
   asset.** JR proves it. Graphiti is healthy *today*, but adopting it means your
   controllers, scoping, and querying all speak Graphiti — so if it stalls in year 4,
   you're not swapping a serializer, you're rewriting your API layer. **Bet on the
   JSON:API 1.1 spec itself** (a stable, frozen contract), not any gem that implements
   it.

3. **JSON:API and OpenAPI compose awkwardly.** JSON:API's dynamically-shaped compound
   documents are hard to pin down in OpenAPI, which is why the JSON:API gems don't ship
   good OpenAPI generators and Grape (which does) isn't really JSON:API. If airtight,
   tooling-friendly public contracts are a hard requirement, resolve it with JSON:API's
   own schema/profile mechanisms or by generating OpenAPI from request specs (rswag),
   independent of gem choice.

4. **WarpDrive slightly loosens the format coupling.** Per its docs, WarpDrive is
   *semi-opinionated*: JSON:API is the **recommended** cache format (least friction), but
   any API works via a request handler that normalizes responses into the cache. JSON:API
   is the path of least resistance, not a hard constraint — which gives the
   "clean public contract" goal more room to drive the decision.

---

## Part 4 — Versioning

### Options for a public JSON:API

JSON:API is touchy about versioning: the media type is `application/vnd.api+json`, and
the 1.1 spec only permits `ext` and `profile` media-type parameters — a custom
`;version=2` parameter is **non-conformant**. The spec-native evolution story is
**profiles/extensions + additive, non-breaking changes**.

| Style | Example | Fit |
|---|---|---|
| **URL path** | `/api/v1/queries` | ✅ Most public-/CDN-/OpenAPI-friendly; leaves the media type pristine. Cheapest. |
| **Date-pinned header** (Stripe-style) | `Discourse-Version: 2026-06-01` | ✅ "Never breaks" gold standard; bigger infrastructure commitment |
| **Media-type param** | `…+json;version=2` | ❌ Non-conformant in JSON:API 1.1 |
| **Profiles/extensions** (JSON:API-native) | `…+json;profile="…"` | ✅ For *additive* semantics within a version; not a major-version boundary |

### Stripe's date-based versioning (the "never breaks" model)

Reference: Stripe engineering, *"APIs as infrastructure: future-proofing Stripe with
versioning"* (Brandur Leach). The format (dates) is the visible part; the architecture
underneath is the substance:

- Internally, code always works with the **latest** representation; business logic never
  branches on version.
- Each API key is **pinned** to a version (default = version active when the key first
  made a call; overridable per-request via a `Stripe-Version`-style header).
- On the way out, the response runs through a **chain of small, ordered
  transformations** — one per breaking change — that downgrade the modern object into
  the shape the caller's pinned version expects (mirror of that on the request side).

So "never breaks" is a **transformation pipeline at the serialization seam**, plus the
discipline to write one reversible module per breaking change, maintained until that
version is sunset.

Implications for us:

- **It's a cleaner fit with full JSON:API than URL versioning.** A *separate* header is
  not a media-type param, so it leaves `application/vnd.api+json` pristine — sidestepping
  the conformance snag media-type versioning hits. The two compose: stay additive
  (JSON:API's "additive is non-breaking") for the ~90% of changes that are additive, and
  spend a version transformation only on genuinely breaking ones.
- **It pushes (mildly) toward thin-layers over Graphiti.** The transformation pipeline
  lives in the serialization seam — the layer the thin-layers approach keeps yours and
  swappable. Bolting Stripe-style gates onto Graphiti means post-processing the
  framework's own rendered output, which fights it.
- **Don't build the machinery for v1 — design *for* it.** The pipeline is a standing
  tax (every breaking change = a new module + a wider test matrix). For a greenfield API,
  build the architecture that makes adopting it cheap later — **(a)** always-latest
  internal representation, **(b)** per-key version pin, **(c)** a serialization seam you
  can insert transformations into — then stay additive as long as possible and stand up
  the pipeline only when the first unavoidable breaking change arrives.

### Recommendation

- **URL `/api/v1/`** is cheaper and perfectly fine if breaking changes will be rare and
  asking clients to migrate is acceptable.
- **Stripe-style date/header versioning** is the gold standard when we want to *promise
  the contract never breaks* — attractive for a decade-long public API with a large
  self-host + plugin ecosystem — but it is an ongoing infrastructure commitment, not a
  config flag.
- Either way, **design v1 around an always-latest internal representation + a
  serialization seam**, so the heavier model can be adopted later without a rewrite.
- **Graphiti note:** its auto-generated `schema.json` + CI backwards-compat check is a
  genuine contract-drift *alarm* (catches dropped filters, changed default sorts, type
  changes) — a real asset for a public contract that the thin-layers path doesn't give for
  free. But it only catches *schema-level* breaks, and Graphiti has no versioning
  machinery: it gives you the breaking-change alarm, not the Stripe-style downgrade
  pipeline (which would fight its serialization ownership anyway).

---

## Part 5 — Sketches: `Query` two ways

Illustrative shapes (not exact APIs), public + versioned, with `user`/`groups` as real
JSON:API relationships.

### A) Thin-layers — ActionController + jsonapi.rb + `Service::Base`

```ruby
# config/routes.rb
namespace :api, defaults: { format: :jsonapi } do
  namespace :v1 do
    resources :queries
  end
end
```

```ruby
# serializer — swappable; the only JSON:API-specific dependency
class Api::V1::QuerySerializer
  include JSONAPI::Serializer
  set_type :query
  attributes :name, :description, :sql, :last_run_at, :hidden
  attribute(:is_default) { |q| q.id.negative? }
  attribute(:param_info) { |q| q.params.map(&:to_hash) }   # derived, stays an attribute
  belongs_to :user
  has_many :groups
end
```

```ruby
# controller — thin; query semantics are explicit opt-in; logic lives in the service
class Api::V1::QueriesController < Api::V1::BaseController
  include JSONAPI::Fetching      # include + sparse fieldsets
  include JSONAPI::Filtering     # filter[...] via Ransack
  include JSONAPI::Pagination

  def index
    scope = jsonapi_filter(policy_scope(Query.visible), %i[name description]).result
    page, meta = jsonapi_paginate(scope)
    render jsonapi: page, include: jsonapi_include, meta:
  end

  def create
    with_service(DataExplorer::CreateQuery) do
      on_success { |query:| render jsonapi: query, status: :created }
      on_failed_policy(:can_create) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render jsonapi_errors: contract.errors, status: :unprocessable_entity
      end
    end
  end
end
```

```ruby
# service — Discourse's own framework owns validation + permissions + writes
module DataExplorer
  class CreateQuery
    include Service::Base

    params do
      attribute :name, :string
      attribute :description, :string
      attribute :sql, :string
      attribute :group_ids, :array, default: []
      validates :name, presence: true
    end

    policy :can_create

    transaction do
      step :create_query
      step :assign_groups
    end

    private

    def can_create(guardian:) = guardian.is_admin?

    def create_query(params:)
      context[:query] = Query.create!(params.slice(:name, :description, :sql))
    end

    def assign_groups(params:, query:)
      params.group_ids.each { query.query_groups.find_or_create_by!(group_id: it) }
    end
  end
end
```

**Character:** every layer is yours and swappable; Guardian + `Service::Base` unchanged;
the JSON:API query surface is explicit (you allowlist filters, opt into includes). More
code per endpoint, near-zero lock-in. Best fit for the Stripe-style serialization seam.

### B) Graphiti — the Resource owns querying

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :queries
  end
end
```

```ruby
# resource — attributes, filters, relationships, writability in one place
class Api::V1::QueryResource < ApplicationResource
  self.model = DiscourseDataExplorer::Query
  self.type  = :queries

  attribute :name, :string
  attribute :description, :string
  attribute :sql, :string
  attribute :last_run_at, :datetime, writable: false
  attribute :is_default, :boolean, writable: false do
    @object.id.negative?
  end

  filter :name, :string do
    eq { |scope, value| scope.where("name ILIKE ?", "%#{value}%") }
  end

  belongs_to :user
  many_to_many :groups

  def base_scope
    Query.visible                      # ← Guardian/scoping must be threaded in here
  end
end
```

```ruby
# controller — almost empty; filter/sort/page/sideload all come from the Resource
class Api::V1::QueriesController < Api::V1::BaseController
  def index
    render jsonapi: QueryResource.all(params)        # the whole query surface, free
  end

  def create
    query = QueryResource.build(params)
    if query.save                                    # ← default AR persistence; override `save` to delegate to a service
      render jsonapi: query, status: :created
    else
      render jsonapi_errors: query
    end
  end
end
```

**Character:** the entire JSON:API query surface for `index` is one line. The trade-offs
are concentrated exactly where we care most:

- **Authorization is 100% DIY** — Graphiti ships no auth layer. Our
  `user_can_access_query?`, group access, and `hidden` filtering would spread across
  `base_scope` (row-level) and guard methods (`attribute :sql, readable: :can_see?`), with
  Guardian reached via `context.current_user.guardian` — rather than the centralized
  Guardian/service flow we have today. Authz on nested writes is a known rough edge in the
  project (long-standing open issues).
- **`Service::Base` is pluggable, not displaced** — you're encouraged to override
  `build`/`save`/`delete` (not `create`/`update`/`destroy`), so `save` *can* delegate to a
  service. The catch is **side-posting** (saving a model + its whole relationship graph in
  one request) — Graphiti's signature write feature — which pulls against
  one-service-per-operation. Realistically you keep services *or* lean into side-posting,
  not both cleanly.

That concentrated cost (plus the framework lock-in) is the trade against the query-surface
win.

### Same wire response from either

```jsonc
// GET /api/v1/queries/123?include=user,groups&fields[query]=name,sql
{
  "data": {
    "type": "query", "id": "123",
    "attributes": { "name": "Top posters", "sql": "SELECT ..." },
    "relationships": {
      "user":   { "data": { "type": "user",  "id": "1"  } },
      "groups": { "data": [{ "type": "group", "id": "10" }] }
    }
  },
  "included": [
    { "type": "user",  "id": "1",  "attributes": { "username": "loic" } },
    { "type": "group", "id": "10", "attributes": { "name": "staff" } }
  ]
}
```

This is exactly what `relations` + `colrender` reinvents by hand today — and exactly
what WarpDrive's cache wants natively.

---

## Part 6 — Graphiti deep-dive: operational caveats & contract notes

From an exhaustive read of the Graphiti guides (cross-checked against the gem source). These
are the subtleties that don't show up in a feature matrix — the things a spike must prove out.

### Strengths confirmed (beyond the matrix)

- **Reads are strict-by-default — nothing is silently ignored.** An unknown filter/sort/include,
  an unsupported operator, an out-of-allowlist value, or a coercion failure all *raise*
  (`Graphiti::Errors::*`). Great for a public contract (no speculative params; bugs surface
  immediately) — but you must map every error class to an HTTP status via `register_exception`.
- **The `SchemaDiff` contract guard is structural/behavioral, not field-only.** It flags as
  backwards-incompatible: removed attrs/filters/sorts/relationships, type changes,
  `readable: true` → guarded, operator removals, allowlist tightening, a filter becoming
  `required`/`single`, **and adding/changing a `default_sort` or `default_page_size`**. It runs
  *inside the test suite* (`GraphitiSpecHelpers::RSpec.schema!`); `FORCE_SCHEMA=true` is the
  deliberate "yes, I'm breaking it" override. This is a real, CI-enforceable public-contract
  guardrail — stronger than the matrix implies, and something the thin-layers path doesn't get
  for free. (Caveat: it only runs over resources loaded during the test boot, and `FORCE_SCHEMA`
  must never be set in normal CI.)
- **N+1 avoidance is structural.** Sideloads are *separate `IN`-filtered queries per
  relationship* (not JOINs, not per-row), so query count scales with include *depth*, not row
  count. `on_extra_attribute` lets expensive derived fields opt in only when requested (with a
  scope hook to eager-load), and adding `extra_attribute`s later is non-breaking.
- **Cursor pagination is built in** (`page[after]`/`page[before]`, `cursor_paginatable`) —
  relevant for Discourse's large, append-heavy tables.
- **Non-AR / synthetic IDs are first-class** — this dissolves the negative-ID `Query` worry. The
  only hard rule is `model.id` must be *unique*; negative/UUID/derived IDs are fine. The Null
  adapter + a custom `resolve` (or a custom `Abstract` adapter) models the virtual default
  queries and derived `params` cleanly, and the adapter's `save`/`delete`/`transaction` methods
  are the **clean delegation seam to `Service::Base`** for non-AR resources.
- **Declarative cross-filter constraints:** `filter_group(names, required: :one|:all)` and
  `dependent:` express "must scope by category or tag before searching" without controller logic.

### Operational caveats (design around these)

1. **Concurrency is ON by default in production** (`cache_classes` true → sideloads run on
   separate threads). The docs warn that thread-locals are dropped — **the spike showed this
   warning is stale**: Graphiti ≥ 1.10 (`Scope#future_with_context`) snapshots
   `Thread.current` storage *and* Ruby 3.2 `Fiber[]` storage into each worker thread, and
   wraps tasks in the Rails executor (proper AR connection handling). `Thread.current`,
   `Graphiti.context`, Guardian, and the multisite db all survived the thread hop in our
   probe (spike log, step 4). Remaining real caveats: **(a)** the copy is *shallow* — workers
   share references, so mutable thread-local state can race; **(b)** the thread-pool executor
   is **memoized per process** (a `Promises.delay`), so `concurrency` must be set before the
   first Graphiti query (initializer) and cannot be toggled at runtime; **(c)** AR pool must
   cover `1 + concurrency_max_threads` (default 4).
2. **`base_scope` does NOT protect writes.** Reads flow through `base_scope`; create/update/
   destroy bypass it entirely. A `base_scope` that scopes "visible records" gives zero write
   protection — write authz must live in guards / persistence hooks (→ Guardian + `Service::Base`).
3. **Everything is writable by default.** `attributes_writable_by_default = true` and
   relationships default `writable: true`. On a public write API a newly-added attribute is
   silently accepted on POST/PUT — flip `self.attributes_writable_by_default = false` in
   `ApplicationResource` and opt in explicitly.
4. **Side-posting authorizes per-resource, not per-graph.** Each nested record runs through *its
   own* resource's `build`/`save`/hooks/validations inside one transaction — a guard on the
   parent is insufficient; enforce Guardian on *every* writable resource. The only hook that sees
   the whole assembled+validated graph is `before_commit`. This is the crux of the
   `Service::Base`-vs-side-posting tension: cleanly, it's services *or* side-posting.
5. **Tighten defaults for public exposure:** `max_page_size` defaults to **1,000**, and
   **Vandal's schema route exposes the entire contract with no auth**. Lower the cap; don't mount
   Vandal in production (or gate it behind admin).

### Sharp subtleties worth filing away

- **`filter eq` is case-*insensitive*; `eql` is case-*sensitive*** — easy to get backwards, and a
  real behavior/security difference on a public API.
- **Guard arity is asymmetric:** `readable:` guards receive the model (per-record,
  Guardian-friendly); `filterable:`/`sortable:` guards are request-level only (no model). Row-level
  visibility must live in `base_scope`, *not* attribute guards — and a `readable:` guard hides the
  field without removing the row, so `stat total: [:count]` can over-count.
- **You can't paginate a `has_many` sideload across multiple parents** (`UnsupportedPagination`) —
  model "top N children" as a `has_one`/faux-`has_one`. And `has_one` links resolve to an *index*
  action, so following one returns an **array** (take the first).
- **Deep-query syntax is asymmetric:** deep *filter* accepts both `filter[positions.title]` and
  `filter[positions][title]`, but deep *sort/pagination* accept only the bracket/type form
  (`sort=departments.name`). Pin the exact accepted forms in public docs.
- Each sideload child **must** expose its FK as a filterable attribute or the sideload errors
  (`MissingSideloadFilter`).
- **Remote resources** (microservices) are read-only, request `page size 999` and *silently
  truncate* beyond it, and **auto-forward the caller's `Authorization` header** to the remote
  (token-leak vector). Out of scope for a monolith, but worth knowing.

### ⚠️ Writes are a Graphiti dialect, not vanilla JSON:API

Graphiti's **reads** are clean JSON:API, but its **writes diverge from the spec**, and WarpDrive
request-handlers would have to speak that dialect:

- **`method`** (`create`/`update`/`destroy`/`disassociate`/`associate`) lives *inside* relationship
  resource identifiers — not a JSON:API concept.
- **`temp-id`** instead of JSON:API's standard **`lid`** for client-generated ids.
- Side-posting puts nested **attributes in the top-level `included`** (a write-direction use of
  `included`, which the spec mostly defines for reads).
- Plus `extra_fields[]`, `stats[]`→`meta.stats`, the `{{...}}`/`[...]` filter-value encodings,
  `?links=true`, and `202`-deferred writes.

So the "portable, gem-agnostic contract" argument holds for **reads** but **weakens for writes**:
adopt Graphiti and your public *write* contract is partly Graphiti-shaped, making it harder to swap
the gem later or to let a third party use a vanilla JSON:API client. Weigh this against the
"standardize on the spec, not the gem" principle in Part 6/7.

**Worse than awkward — it's an active data-loss footgun (verified in step 5).** Graphiti
**relationships are writable by default**, *independently* of `attributes_writable_by_default`.
A write payload can therefore side-post `method: "create"/"update"/"destroy"/"disassociate"`
on a relationship and Graphiti will **persist those operations on the related records**,
bypassing your service entirely. In the spike, a `groups` sidepost with `method: "destroy"`
**deleted the `Group` row**. Mitigation is mandatory and must be explicit: lock every
relationship `writable: false` (ideally as a default policy on `ApplicationResource`) and route
all writes through attributes + a service.

### Verify-in-spike checklist (Graphiti-specific)

- [x] Guardian threads cleanly through `base_scope` + guards **and survives sideloads with
      `concurrency` on** — verified in step 4 (access matrix + instrumented thread probe);
      thread/fiber storage is propagated by Graphiti ≥ 1.10. Residual: shallow-copy races,
      executor memoization, pool sizing.
- [x] `save` delegating to a `Service::Base` feels workable — verified in step 5 (stash payload
      in `assign_attributes`, copy errors onto the shell for 422). Nested-write authz resolved
      **by design**: relationships are locked `writable: false`, so side-posting is outside our
      write contract entirely (see the data-loss finding).
- [x] Nested (side-post) validation errors & `temp-id` → real-id mapping — **moot by design**:
      side-posting is disabled in our contract (relationships read-only; writes flow through
      attributes + services). Would need answering only if a future decision re-enables it.
- [ ] Pagination-`links` shape; lower `max_page_size`; gate/skip Vandal in prod.
- [ ] Self-referential relationships (e.g. category parent/children) — **undocumented in Graphiti**,
      needs a spike if we model recursive structures.

---

## Part 7 — Recommendation & open questions

### Recommendation

1. **Standardize on the JSON:API 1.1 spec, not a gem.** The two sketches above are
   deliberately wire-identical so the implementation can change without changing the
   public contract. That portability is the strongest argument for treating the spec as
   the durable thing.
2. **Spike with Graphiti first** to *experience* full JSON:API fast and stress-test how
   much of the query surface WarpDrive actually exercises — it's the whole spec for
   almost no code. Use the **Part 6 verify-in-spike checklist** to prove out the caveats
   (concurrency/thread-locals, write authz, the write-dialect divergence).
3. **Make the commitment decision separately.** If the experience confirms we want the
   whole query surface and we can accept the bus-factor/lock-in, keep Graphiti. If not,
   the **thin-layers** approach gives the same wire contract with a decade of
   swappability and our `Service::Base`/Guardian patterns intact — and is the better host
   for a Stripe-style versioning seam.
4. **Design v1 for versioning from day one** (always-latest internal representation +
   serialization seam + per-key version pin) without building the full transformation
   pipeline yet.

### Open questions

- **Versioning style:** URL `/v1` (cheap, simple) vs Stripe-style date/header pinning
  ("never breaks", more infrastructure)? Tied to: how often do we expect breaking
  changes, and how unacceptable is forcing clients to migrate?
- **Contract tooling:** OpenAPI (generated from request specs) vs JSON:API's own
  schema/profile mechanisms? Given the JSON:API↔OpenAPI tension.
- **Public vs internal scope:** how much of the JSON:API query surface do we expose
  publicly vs lock down?
- **The negative-ID default queries:** include them in the experiment or bracket them
  off?
- **The `Result` resource:** how to model tabular rows + the `included` typed entities —
  the part that genuinely tests JSON:API for non-CRUD payloads.

### References

- [JSON:API 1.1 specification](https://jsonapi.org/format/)
- [Graphiti](https://www.graphiti.dev/) · [releases](https://github.com/graphiti-api/graphiti/releases)
- [jsonapi.rb](https://github.com/stas/jsonapi.rb)
- [jsonapi-resources](https://github.com/JSONAPI-Resources/jsonapi-resources) (cautionary — dormant)
- [Grape](https://github.com/ruby-grape/grape) · [grape-jsonapi](https://github.com/emcousin/grape-jsonapi)
- [WarpDrive guides](https://warp-drive.io/guides/) · [`@ember-data/json-api`](https://www.npmjs.com/package/@ember-data/json-api)
- Stripe — *APIs as infrastructure: future-proofing Stripe with versioning* (Brandur Leach)

---

## Part 8 — Graphiti spike log (running)

Hands-on findings from the spike, in step order. Code lives in this plugin:
`app/resources/discourse_data_explorer/`, the `Api::V1::QueriesController`, and the
`/data-explorer/api/v1` routes. Spike plan: (0) deps → (1) read-only resource →
(2) relationships → (3) query surface → (pagy keyset pagination) → (4) Guardian +
concurrency probe → (5) writes via `Service::Base` → (6) schema contract guard.

### Step 0 — dependencies (done)

- `graphiti 1.10.2` + `graphiti-rails 0.4.1` install cleanly against Rails 8.0.5 /
  Ruby 3.4.7; 10 new gems total (`dry-*` tree, `jsonapi-renderer`/`-serializable`,
  `graphiti_errors`, `rescue_registry`); Rails not bumped.
- **Plugin-vendored gems were a dead end:** `PluginGem` installs with
  `--ignore-dependencies`, so Graphiti's whole tree would need explicit, ordered `gem`
  lines in `plugin.rb`. We used the root `Gemfile` instead — which turns out to be the
  established pattern for plugin deps (`# for discourse-…` entries already exist for
  automation/zendesk/subscriptions/github/ai).
- **graphiti-rails injects globally**: an `around_action` (Graphiti context) and
  RescueRegistry land in *every* controller via `ActiveSupport.on_load(:action_controller)`
  (the old `include Graphiti::Rails` is deprecated). Blast radius is contained though:
  the global `Exception` handler is gated to `handled_exception_formats = [:jsonapi]`,
  so existing HTML/JSON error rendering is untouched. It also registers the `:jsonapi`
  MIME type, parameter parser, and `render jsonapi:`/`jsonapi_errors:` renderers, and
  sets `Graphiti.config.concurrency = !test? && cache_classes` (→ off in dev, on in prod).

### Step 1 — read-only `QueryResource` (done)

- `GET /data-explorer/api/v1/queries` returns a compliant JSON:API document with
  `Content-Type: application/vnd.api+json` through the full Discourse controller stack.
  Resources autoload from `app/resources/` via the engine, no extra wiring.
- **Graphiti's AR adapter paginates via Kaminari** (`.page/.per/.padding`), which
  Discourse doesn't ship → `NoMethodError` out of the box. Escape hatch: a custom
  `paginate do |scope, page, per, ctx, offset|` block on `ApplicationResource` (plain
  `limit/offset`) — no Kaminari, no adapter subclass.
- **Graphiti's built-in "cursor" pagination is offset-in-a-token**, not keyset: the
  `page[after]` cursor literally decodes to `{offset: N}` and still emits `OFFSET` SQL.
  Real keyset pagination is planned as its own step using the **pagy** gem inside the
  custom `paginate` block.
- `base_scope` = `id > 0` brackets off the negative-ID virtual default queries for now.
- Red herring to remember: in-process integration tests 403 with an HTML "Blocked
  hosts" page unless the session uses a permitted host (`session.host! "localhost"`) —
  Rails Host Authorization, not Discourse auth.

### Step 2 — relationships / compound document (done)

- `?include=user,groups` produces real linkage + `included` — exactly what the legacy
  `relations`/`colrender` hand-rolls. Sparse fieldsets work
  (`fields[queries]=name,sql&fields[users]=username`), and a non-included relationship's
  query is skipped entirely.
- **Negative IDs flow through untouched**: the system user (`id: -1`) serialized fine in
  both linkage and `included` — good omen for the virtual default queries.
- **Query economics confirmed**: 3 data queries for index + 2 includes (one `IN`-filtered
  query per relationship, no JOINs, no N+1).
- **`many_to_many` is the priciest wiring** (deep-dive confirmed hands-on). It needed:
  1. an explicit `foreign_key: { query_groups: :query_id }` (no inference),
  2. `::Group` gaining a `query_groups` AR association — Graphiti's `assign_each`
     matches children via `group.query_groups` — done with a one-line
     `reloadable_patch` in `plugin.rb`,
  3. a `filter :query_id` on `GroupResource` (the sideload queries through it), shaped
     as `includes(:query_groups).where(...)` so assignment doesn't N+1.
  Verified in the adapter source: read-path assignment populates the association's
  in-memory `@target` only — the DB-writing `<<` path runs solely in `:create`/`:update`
  namespaces (side-posting).
- Graphiti-ism: non-included relationships still render as
  `"groups": { "meta": { "included": false } }` instead of being omitted.

### Step 3 — query surface + strictness (done)

Reproduced everything the legacy `index` does by hand, declaratively: `filter :search`
(same ILIKE on name/description), `filter[name][match]`, opt-in sorts incl. a custom
`sort :username` join (LEFT, `NULLS LAST`), `default_sort last_run_at desc`, and
`stats[total]=count` → `meta.stats` which **respects active filters** (replaces
`total_rows_queries`). Unknown/disallowed params 400 instead of being silently ignored.

- **DSL opt-in asymmetry** (after flipping `attributes_filterable/sortable_by_default`
  to `false`): `filter :name` *re-enables* a non-filterable attribute (source comment:
  "We're opting in to filtering, so force this"), but `sort :name` only *checks* and
  raises `InvalidAttributeAccess` — sorting opts in via `attribute ..., sortable: true`.
  And since `#find` + sideloads work through `filter[:id]`, hardened resources must
  re-declare `filter :id` or show/includes break.
- **Error-rendering collision (headline finding):** Graphiti's strict client-input
  errors mostly aren't registered by graphiti-rails (→ 500 by default), and its
  RescueRegistry bodies render via Rails' `exceptions_app` — which Discourse replaces
  with `Middleware::DiscoursePublicExceptions` (`config/application.rb:175`). In
  Discourse, registered handlers fix the *status* but the JSON:API *error body* never
  renders. Resolution: Discourse-idiomatic `rescue_from` in the API controller
  (see `CLIENT_INPUT_ERRORS` in the spike controller) — all strictness probes then
  return 400 + spec-shaped `errors[]` documents.
- Minor: Graphiti error `detail` strings leak internal class names
  (`DiscourseDataExplorer::QueryResource: Tried to filter on :sql ...`) — fine for
  devs, would want sanitizing for a public contract.

### Step 4 — Guardian + concurrency probe (done)

Row-level auth lives in one place — `QueryResource#base_scope` reading `context.guardian`
(helpers on `ApplicationResource`) — plus a request-level `readable: :admin?` guard on the
`hidden` attribute. Access matrix verified (admin → all + `hidden` attr; group member →
only group-bound queries, no `hidden`; outsider/anon → nothing), incl. over real HTTP:
anonymous `show` of a forbidden query is a clean **404** (no existence leak), matching the
legacy `Discourse::NotFound` behavior.

- **Composition note:** express group access as a **subquery**
  (`where(id: QueryGroup.where(group_id: …).select(:query_id))`) rather than
  `joins + distinct` — `SELECT DISTINCT` breaks PG when a custom sort (username) adds its
  own join + order column. Verified: member scope + `sort=-username` + `include` +
  `stats[total]` compose; the stat count respects the Guardian scope.
- **Guard methods must be public** — the serializer invokes `readable:` guards via a
  public send; a `private` guard raises `NoMethodError` at render time.
- **The concurrency landmine is mostly defused** (big finding — corrects Part 6 caveat #1):
  with `concurrency = true`, sideloads genuinely ran on worker threads, and
  `Thread.current[...]`, `Graphiti.context`, Guardian, and the multisite db **all
  survived**. Graphiti ≥ 1.10 snapshots thread + fiber storage per task
  (`Scope#future_with_context`) and wraps tasks in the Rails executor. Remaining caveats:
  shallow copy (shared mutable refs can race), executor memoized per process (set
  `concurrency` in an initializer; runtime toggles are no-ops), AR pool ≥
  `1 + concurrency_max_threads`.

### Step 5 — writes via `Service::Base` (done)

`POST /data-explorer/api/v1/queries` works end-to-end, delegating wholesale to a real
`DiscourseDataExplorer::Query::Create` service (built via the service-authoring skill's
8-phase flow; 12-example service spec, 287/287 non-system plugin specs green). **The core
question is answered: `save` can delegate to `Service::Base` cleanly.**

- **The seam (3 resource overrides):** `build` returns an unsaved shell; `assign_attributes`
  **stashes** the deserialized payload instead of assigning it (this also sidesteps
  `group_ids`, which isn't a model column — no virtual-attribute hack); `save` calls the
  service with the block-matcher DSL. `on_success` returns the created record (→ 201);
  `on_failed_contract`/`on_model_errors` **copy errors onto the shell** so Graphiti's
  persistence layer renders a 422 `jsonapi_errors` document; `on_failed_policy(:can_create_query)`
  raises `Discourse::InvalidAccess`.
- **Wart:** that policy-failure 403 renders as Discourse's HTML/JSON, **not** a JSON:API
  errors document — the same `exceptions_app` collision from step 3. Contract/model errors
  *do* render as proper JSON:API 422s (they go through Graphiti's renderer, not the
  exception path).
- **🔴 Data-loss footgun found (now also in Part 6):** Graphiti **relationships are writable
  by default**, separate from `attributes_writable_by_default`. A `groups` sidepost with
  `method: "destroy"` **deleted the `Group` row**, bypassing the service. Fix: every
  relationship `writable: false`. This was the single most important finding of the whole
  spike — the dangerous default wasn't in our code, it was Graphiti's relationship default.
- **Hardening flag:** writes also needed `attributes_writable_by_default = false` (else any
  attribute, e.g. `hidden`/`user_id`, is mass-assignable on POST).
- **Bugs surfaced by building it properly:** two latent in the legacy create path — (1)
  non-atomic create+bind, (2) bogus `group_ids` silently writing orphan join rows (no FK
  constraints on `data_explorer_query_groups`) — both fixed in the new path (transaction +
  `all_requested_groups_exist` policy); and one of our own — explicit `group_ids: null` from
  the wire crashed the contract (`nil.reject`), fixed with `Array(group_ids)`.

### Step 6 — schema contract guard (done)

The `SchemaDiff` contract guard works as advertised, and the error output is good enough to
build a public-contract workflow on. Implementation:
`spec/integration/api_schema_spec.rb` + committed baseline `schema.json` at the plugin root.

- **No extra gem**: skipped `graphiti_spec_helpers` — the spec calls
  `Graphiti::Schema.new(resources).generate` + `Graphiti::SchemaDiff#compare` directly with an
  explicit resource list (also avoids `Schema.generate`'s unconditional
  `Rails.application.eager_load!`). `FORCE_SCHEMA=true` remains the documented
  "intentional break / version bump" override.
- **The contract is rich**: per-attribute `readable`/`writable` — including
  `hidden: readable "guarded"`, i.e. **the Guardian guard is contract-visible** — plus filters
  with operators, sorts, `default_sort`, relationships, types.
- **Live-fire verified**: changing `default_sort` + removing `filter :search` failed the spec
  with exact violations —
  `default sort changed from [{last_run_at: "desc"}] to [{name: "asc"}]` and
  `filter :search was removed.` — and the failed run **did not overwrite the baseline** (the
  diff gate runs before the write).
- Note: the schema's `endpoints` section came out empty for us (endpoint inference doesn't match
  our manually-drawn routes + `validate_endpoints = false`) — resource-level contract coverage is
  unaffected; endpoint coverage would need `primary_endpoint` declarations.

### Step 7 — keyset pagination via pagy (done)

True keyset/cursor pagination works inside Graphiti's custom `paginate` block using
**pagy ~> 43.0** (`Pagy::Keyset.new(set, page:, limit:)` directly — the `pagy(:keyset, …)`
controller helper is just request-param sugar we don't need). Follow-up of the closed
PR #36065 (same Gemfile approach; its `Current.request` machinery is unnecessary here since
our cursor rides the document `meta`, not URL helpers).

- **Wire format:** engaged by **`page[cursor]`** — deliberately *not* JSON:API's
  `page[after]`, because Graphiti eagerly decodes `page[after]`/`[before]` as Base64 JSON
  *hashes* of its own offset-cursors (`query.rb#decode_cursor`) and 500s on a foreign
  cutoff (pagy's cutoff is a Base64 JSON *array*, e.g. `"WzExXQ" == [11]`). Next cutoff is
  returned in `meta.page.next_cursor` (the paginate block hands it to the controller via
  Graphiti's context; the controller forces `records.data` before building meta).
- **Verified SQL:** page 2 runs `WHERE id < 11 ORDER BY id DESC LIMIT 3` — a true index
  seek, no `OFFSET`, with pagy's limit+1 look-ahead; zero overlap between pages; `nil`
  cursor on the last page; garbage cursors degrade gracefully to page 1
  (`Keyset.decode` rescues to nil); offset mode (`page[number]/[size]`) unchanged; Guardian
  `base_scope` composes into every variant.
- **Design call to revisit for a real API:** cursor mode **pins its own ordering**
  (`id desc`) — the default sort's `last_run_at` is nullable, and keyset over nullable
  columns is a correctness trap. "Cursor pagination × arbitrary client sorts" is a genuine
  contract-design question (most real APIs restrict cursor mode to fixed orderings).
  Currently a client-supplied `sort` is silently overridden in cursor mode — a real
  implementation should reject the combination instead.

### CI fallout — graphiti-rails rake tasks pollute Object (fixed, upstream bug)

Merely having graphiti-rails in the bundle broke **core** request specs on CI
(`undefined method '[]' for an instance of ActionDispatch::Integration::Session` on every
`session[:key]` assertion). Root cause: `graphiti-rails-0.4.1/lib/tasks/graphiti.rake`
defines its helpers (`session`, `setup_rails!`, `make_request`) with bare `def` inside
`namespace :graphiti` — **rake namespaces are not lexical scopes**, so once tasks are
loaded these become private methods on `Object` (it also does
`include RescueRegistry::RailsTestHelpers` into `main`). `Object#session` then shadows the
request-spec `session` helper. This bites even with plugins disabled, because the gem
loads from the root Gemfile.

Workaround: `config/initializers/100-graphiti-rake-pollution.rb` wraps
`Rails.application.load_tasks` and scrubs the three methods, guarded by source location so
only graphiti's definitions are ever removed. Verified: the broken core specs pass again
and the plugin's own rake-task specs still pass. **This is an upstream graphiti-rails bug
worth reporting** — and another data point for the "graphiti-rails touches the whole app"
caveat (Part 8, step 0): the blast radius now includes `Object` itself.

### Spike status: complete

All planned steps done (0–7). Every Graphiti question answered hands-on; working code +
specs behind each claim. See Part 6 for the distilled caveats and Part 7 for the
recommendation.
