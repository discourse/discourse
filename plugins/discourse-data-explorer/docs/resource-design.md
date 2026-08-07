# JSON:API Kit — Resource Class Design

**Status:** design settled in a pairing session (2026-07-21) and **built the same day**:
`ResourceBase` (22 unit examples) plus the queries migration — `QueryResource`/
`UserResource`/`GroupResource` replaced the Kit serializers and the controller's `jsonapi`
block, with the full suite green throughout (behavior-preserving by construction). Still
open from the plan: types in the contract-guard baseline, the real resource registry.
**API key scopes** designed and built 2026-07-30 (§8). **Publication and support** (the
`internal` keyword) decided 2026-07-31 from the RFC discussion (§9), unbuilt.
**References:** [versioning design](./versioning-design.md) · [plugins design](./plugins-design.md) · [API docs generation](./api-docs-generation.md).

Guiding principle, stated once for the whole Kit: this is a **new API** — every case the
JSON:API spec describes will exist at some point, so designs should generalize with the
full spec surface in mind. "No use case yet" may sequence *implementation*; it is not an
argument for a shape that forecloses a spec case. (Breaking a design later because
something was missed or a better solution appeared is normal evolution — the principle
targets *knowingly* choosing a foreclosing shape, not perfection.)

---

## 1. Why a resource class — the convergence

Every recent design thread ends at the same missing home:

- **Types** (docs generation): mandatory explicit types have no slot in
  jsonapi-serializer's DSL.
- **`description` prose** (docs): same — no slot.
- **`writable:` flags** (`from_resource` contract imports): same.
- **Query-surface declarations**: the per-resource position (same type ⇒ same surface)
  wants filters/sorts declared at resource level, not per controller — already a noted
  follow-up in the versioning doc.
- **Scope discipline** (plugins doc, B): "a plugin's own resources keep their declarations
  in resource classes" — which only makes sense once resource classes exist.

Before this design landed, those declarations were split between the controller's
`jsonapi do … end` block (query surface) and a serializer class (document shape). The
resource class is the merge of the two halves of one concept.

## 2. Shape: the resource *is* the serializer

`ResourceBase` includes `JSONAPI::Serializer` and extends it — a resource class is
directly renderable; no derived serializer, no second class per resource.

**The rule that makes this safe: the gem is private plumbing.** Resources use only
ResourceBase's keywords; each keyword records the Kit's own config (type, description,
writability, query-surface entries) and *then* delegates to the gem's registration
internally, normalizing anything gem-specific (block signatures, the `lazy_load_data`
idiom, the `Array()` splat on related POROs). Nothing downstream ever calls the gem's DSL
directly. Consequence: the gem is swappable — ResourceBase could drop the include and
implement `serializable_hash` itself without touching a single resource class. That escape
hatch matters because jsonapi-serializer is feature-dead (verified earlier); wrapping it
is fine, exposing it as the public declaration surface would not be.

Notable deviation from Graphiti: Graphiti resources are declaration objects that
*configure a separate serializer class* (`apply_attributes_to_serializer`,
`resource/dsl.rb:136`) — has-a, earned because Graphiti sits on a separate rendering
library. Our starting point differs (serializer classes are already written directly), so
is-a is the smaller step: same keyword-mapping work, one less layer, equal swappability
given the plumbing rule.

**The `ApplicationResource` layer** (the ApplicationRecord convention): resources inherit
from an application-owned abstract base, never from `ResourceBase` directly — the home
for app-wide declarations (shared attributes, page defaults, …). Declarations inherit
down: `ResourceBase` mirrors the gem's own inheritance hook for the Kit-side definitions
(shallow dups — a subclass sees the parent's declarations and adds its own without
mutating the parent). Without that mirror, a parent-declared attribute would *render* on
the subclass (the gem inherits its state) while the docs/contract metadata silently missed
it.

## 3. The DSL

```ruby
class QueryResource < ApplicationResource
  type :queries

  attribute :name, :string, writable: true
  attribute :description, :string, writable: true
  attribute :query, :string, writable: true, description: "The SQL source of the query.", &:sql
  attribute :ran_at, :datetime, &:last_run_at
  attribute :hidden, :boolean, if: proc { |_record, params| params[:guardian]&.is_admin? }

  has_one :user, resource: UserResource
  has_many :groups, resource: GroupResource

  filter(:q, :string, description: "Matches name or description.") { |scope, value| … }
  sort :name
  sort :ran_at, column: :last_run_at, nulls: :last
  default_sort ran_at: :desc

  includes :user, :groups, "user.groups"
  stat :total, :count
  page max: 100, default: 20

  base_scope { … } # declared here; still instance_exec'd in controller context
end
```

Keyword inventory:

| Keyword                                                 | Origin                                       | New metadata                                             |
| ------------------------------------------------------- | -------------------------------------------- | -------------------------------------------------------- |
| `type`                                                   | serializer (`set_type`)                      | —                                                         |
| `description "…"`                                        | new (docs)                                   | resource prose → docs schema + tag description            |
| `attribute name, type, …, &block`                        | serializer                                   | **type (mandatory, positional)**, `writable:` (default false), `description:`, `example:` |
| `has_one` / `has_many name, resource:`                   | serializer (`belongs_to`/`has_one`/`has_many`) | `resource:` names the Kit resource; `description:`      |
| `filter name, type, &block`                              | controller block                             | **value type** (docs + later coercion), `description:`   |
| `sort name, column:, nulls:, &block`                     | controller block                             | `description:` (no value type — direction only)          |
| `default_sort`, `includes`, `stat`, `page`, `base_scope` | controller block                             | — (moved unchanged)                                      |

Relationship vocabulary: **`has_one`/`has_many`, deliberately without `belongs_to`.** The
FK-placement distinction is an ORM fact with no meaning at the document layer — the
underlying gem treats `has_one` and `belongs_to` identically (same `_id` default, same
to-one rendering; `create_relationship` source) — and it becomes a lie for PORO-backed
resources (no table, no FK). Cardinality is the only wire-relevant fact, and
`has_one`/`has_many` are familiar to every Rails developer.

## 4. Deliberate deviations from Graphiti

Graphiti's DSL is the model ("steal the shape"), with four deviations:

1. **Opt-in query surface.** Graphiti defaults `filterable:`/`sortable:` on per attribute;
   the Kit keeps explicit `filter`/`sort` declarations only (default-on is an
   unindexed-scan surface — decided long ago, unchanged). Considered and declined
   (2026-07-21): `sortable:`/`filterable:` as *opt-in attribute options* — `sort :name`
   with no block already means "sortable attribute", the standalone lines keep the whole
   query surface readable as one block, and the sugar can't express the non-trivial cases
   (`column:`, `nulls:`). If derived *filters* are ever designed, the shape is the
   no-block `filter :name` (symmetric with sorts), not an attribute flag. Deferring
   forecloses nothing — `attribute` takes kwargs, so the sugar stays addable.
2. **`writable: false` by default** (Graphiti defaults on). Nothing enters a write
   contract without an explicit opt-in — what makes `from_resource` imports trustworthy.
3. **`ActiveModel::Type`, not dry-types.** Zero new dependencies, and it is the *same
   registry Service::Base contracts already use* — resource types and contract types share
   one vocabulary, so `from_resource` is a literal `(name, type)` copy (Discourse already
   registers the `:array` type contracts rely on). Graphiti needed dry-types'
   three-directional coercion; the Kit gets read-side coercion from attribute blocks,
   write-side from contracts, and params coercion can ride the same declarations later.
4. **Is-a serializer, not a derived one** (§2).

## 5. What remains in the controller

Endpoint wiring only: `resource QueryResource` (replacing the `jsonapi do … end` block)
and the write actions via `Service::Base`. Execution context is unchanged: blocks are
*declared* on the resource but still `instance_exec`'d in the controller (guardian,
params, current_user) — moving the declaration home does not move the execution context.

**Write actions stay fully explicit — no outcome-defaulting DSL** (decided 2026-07-21,
retiring an earlier `create do service … end` sketch). Framework history is the argument:
when the service framework introduced auto-merged default outcomes, developers couldn't
tell which handlers were in place, and fully explicit won. Instead, the Kit adopts the
*official* controller→service pattern: `Service.call(service_params) do … end`, with
`service_params` overridden once in `BaseController` to
`{ params: jsonapi_deserialize(params), guardian: }` — the deserialized (and already
up-migrated) write document instead of raw params. Endpoint-specific args
`deep_merge` into `service_params` at the call site, per the core convention.

## 6. Interactions with the rest of the design

- **Contract guard**: reads the resource's config and gains **types** — a type change is a
  breaking change the guard currently cannot see (Graphiti's `SchemaDiff` includes types;
  ours should too).
- **Docs generation**: the §7 pipeline chain becomes concrete — response schemas from
  resource declarations; request schemas from contracts via `from_resource` + validator
  introspection.
- **Extensions** (plugins doc): `register_relationship` aligns with `has_one`; per the
  guiding principle the extension API must accommodate to-many attachments
  (`register_has_many`, or `register_relationship` growing the same keyword pair) — design
  settled now, implementation deferred.
- **Versioning**: resources declare the latest shape, renames stay in `VersionChange`s,
  and the derived/virtual sort-filter machinery is untouched — the config moves, the
  semantics don't.
- **`from_resource`** (docs doc, §7): imports `writable:` attributes as `(name, type)`
  pairs — same ActiveModel vocabulary on both sides.

## 7. Migration plan (spike increment)

1. ~~`ResourceBase` with the wrapped keywords~~ — DONE (TDD, 22 unit examples).
2. ~~`QueryResource` replaces `QuerySerializer` + the controller's `jsonapi` block~~ —
   DONE; controller is `resource QueryResource`, and the full suite stayed green
   (the acceptance specs pin the wire contract, so the migration is proven
   behavior-preserving by construction). One descriptor fix rode along: the contract
   guard now records relationship *cardinality* (`to_one`/`to_many`) instead of the gem's
   `belongs_to`/`has_one` labels, which render identically and must not diff.
3. ~~`UserResource` / `GroupResource`~~ — DONE. Still open: contract-guard baseline
   regenerated with **types** added.
4. Still open: the extension registry's `serializer_for` stand-in becomes a real resource
   registry.

## 8. API key scopes (designed and built 2026-07-30)

Origin: a review comment on the RFC draft — *"we should probably try to integrate the API
Scopes system into our DSL and docs. Try to plug into the existing system, but with a nicer
DSL."* The brief is explicitly **plug in, don't redesign**: core's scope model, table,
matcher and admin UI stay exactly as they are, and the centralized mapping hash keeps
serving everything that isn't a Kit endpoint.

### How core's system works (verified in-repo)

- The atom is **`controller#action`**, not a resource and not a URL. A scope row is
  `(resource, action, allowed_parameters)` (`app/models/api_key_scope.rb`) pointing into a
  central mapping: `ApiKeyScope.default_mappings` deep-merged with plugin registrations
  from `add_api_key_scope` (`DiscoursePluginRegistry.api_key_scope_mappings`).
- A mapping entry is `{ actions: %w[ctrl#act …], params: %i[id], methods:, formats:,
  aliases: }`. Enforcement is `ApiKey#request_allowed?` → `ApiKeyScope#permits?` →
  `RouteMatcher#match?`, which checks `controller#action`, HTTP method, format, and *flat*
  param values.
- The admin UI derives its "allowed URLs" list by introspecting the route table
  (`find_urls`), engine route sets included.
- **A key with no scopes bypasses all of this** (global); scopes only constrain granular
  keys.

**The finding that makes this necessary:** a granular key currently *cannot call the Kit
endpoints at all*. `request_allowed?` is `scopes.blank? || scopes.any?(&:permits?)`, so with
no mapping covering our routes, every granular key is denied. Global keys work. Plugging in
is a prerequisite for the new API, not a nicety.

### Decision: declare per endpoint, name after the resource

Scopes gate **routes**, not documents, so the controller is the right home:

- One resource type can be served by several routes at different privilege (an admin
  variant, a nested route under a parent). Declared per resource, one grant would cover all
  of them.
- The resource class doesn't know which actions exist; the controller and the route table
  do. Writes are per-controller in the Kit by design (§5).
- Declaring per resource inverts the Kit's dependency direction (the controller names its
  resource, never the reverse).

What the resource contributes is the **name**, so scope names read like the public
vocabulary (`queries` / `read`, not `json_api_kit/queries#index`).

### Derivation, and why it is route-driven

Nothing is declared by default. The mapping is assembled **lazily from the route table**:
keep the routes whose controller is a Kit controller, constantize it (which triggers
autoload), read its resource type and any override. Deliberately *not* executed in the
class body, and *not* from `BaseController.descendants`: at class-definition time the routes
aren't necessarily loaded, and in development with lazy autoloading `descendants` is
incomplete — a scope would silently be missing from the admin UI in dev only. Route-driven
derivation also means a new Kit endpoint is scoped the moment it is routed, so there is
nothing to forget and no boot-time check to write.

Conventions:

| Derived from | Value |
| --- | --- |
| scope resource | the JSON:API type (`queries`) |
| scope actions | `index`/`show` → `read`; `create` → `create`; `update` → `update`; `destroy` → `delete` |
| `actions:` | `"<controller_path>#<action>"` per routed action |
| `params:` | `[:id]` on member routes — gives admins the existing "restrict this key to specific ids" feature for free |

**`api_scopes` overrides the derivation** where the defaults don't fit — a different scope
name (an admin variant of a type) and/or a different grouping of actions:

```ruby
api_scopes :admin_queries
api_scopes read: %i[index show], write: %i[create update destroy]
```

A declared grouping wins over the default table, and the resource name defaults to the
JSON:API type when only a grouping is given. Member actions keep `params: [:id]` under
whatever name they end up in, since that follows the route, not the grouping.

**Granularity is compatibility-first, not a fix.** Most of the API is far coarser today:
chat exposes exactly one scope (`create_message`), Data Explorer one (`run_queries`). Per
action is already finer than that, and finer grants remain additive later.

**The seam into core** is one addition to `ApiKeyScope.scope_mappings`, which already merges
`default_mappings` with the plugin registry: Kit-derived mappings join that merge. Plugin
-owned Kit endpoints keep going through `add_api_key_scope`, so the enabled/disabled
filtering still applies.

### Built in the spike (2026-07-30, TDD — 16 acceptance examples)

`JsonApiKit::ApiKeyScopes` derives the mapping and registers it; `BaseController
.api_scope_resource` supplies the name; descriptions live in the plugin's client locale.
Zero core changes: the spike registers through the existing plugin API, which is the same
shape core-hosted endpoints will use via the `scope_mappings` seam above. The derived
mapping, verified at runtime:

```ruby
{ read:   { actions: %w[…/queries#index …/queries#show], params: [:id],
            urls: ["/data-explorer/api/queries (GET)", "/data-explorer/api/queries/:id (GET)"] },
  create: { actions: %w[…/queries#create],
            urls: ["/data-explorer/api/queries (POST)"] } }
```

`urls` is filled by core's own `parse_resources!`, so the admin UI lists our routes with no
work on our side.

**Finding that changed the design — registration timing.** Plugin `after_initialize` runs
*before* Rails loads the route table (probed: `Rails.application.routes.routes` is **empty**
there), so registering from `after_initialize` derives nothing and fails silently. The
registration therefore happens **from the routes file, immediately after the Kit's routes are
drawn** (`ApiKeyScopes.register!`), which also keeps the two facts in one place. `register!`
resets the memo first, so a dev route reload recomputes. The real-phase `jsonapi_resources`
route helper would do exactly this as it draws the routes.

The acceptance spec (`spec/requests/…/api_key_scopes_spec.rb`) pins the whole chain: a key
scoped `queries:read` reads but cannot create; a key scoped `queries:create` creates but
cannot read; a key scoped to another resource is refused; `allowed_parameters` restricted to
one id serves that query, refuses another, and refuses the listing (documented consequence,
same as core's id-restricted scopes); an unscoped key is unaffected; and every derived scope
action has its admin-UI translation (client keys are visible server-side, so `I18n.exists?`
is a valid guard).

### Admin UI descriptions: reuse the existing convention

Per-action descriptions already exist and already render as the checkbox tooltip
(`admin_js.admin.api.scopes.descriptions.<resource>.<action>`, read in
`admin/components/admin-config-areas/api-keys-new.gjs` and `api-keys-show.gjs`). Since the
derived scope resource *is* the key segment, a Kit resource needs no new namespace:
`descriptions.queries.read` and friends, with plugin-owned endpoints putting theirs in the
plugin's own client locale file.

Two consequences:

- **A resource-level description has nowhere to render.** The UI shows the resource name as
  a plain table header plus per-action tooltips. Adding a slot would mean changing the
  system we agreed not to touch, so the prose lives in the per-action strings.
- **Those keys are client-side**, so the docs generator (server-side) can't read them. The
  documentation uses what the Kit already declares (the resource `description`, plus
  per-action prose); the admin UI uses i18n. Two audiences, two sources — worth stating so
  nobody wires them together later.

The guardrail is a spec asserting every derived scope has its translation key present —
same shape as the contract guard: the declaration exists, so a missing string is provable
rather than discovered by an admin staring at an empty tooltip.

### Documentation integration (built 2026-07-30)

The document declares both credentials as `apiKey` security schemes (`Api-Key`,
`Api-Username`) with a single document-level requirement listing both (OpenAPI reads a
combined requirement as AND), and every operation carries `x-api-scope` — `queries:read`,
`queries:create` — derived from the same declarations the runtime enforces, so it cannot
drift. The extension is needed because OpenAPI 3.1 requires the `security` scopes array to
be **empty** for non-OAuth2 schemes, leaving nowhere standard to name a scope.

### Traps found while reading core

- **Never set `formats:`** in Kit mappings. `application/vnd.api+json` is not a registered
  Mime type, so `request.formats.first.symbol` is not `:json` and the matcher would reject
  every request. No core mapping uses `formats:` today, so this is a warning for us only.
- **`params:` matching is flat** (`request.parameters[param]`), so `filter[...]`-based
  restrictions are impossible without touching `RouteMatcher`. Member-route `:id` works.
- **`scope_mappings` runs per request** for a granular key, `deep_dup`s the whole default
  hash, and re-walks every route set through `find_urls` for each plugin mapping. That is a
  pre-existing cost we must not add to: the Kit's derived hash is memoized once per boot
  (cleared on reload), never recomputed per call.

### Open questions

- **Admin variants of one type.** Two controllers serving `queries` at different privilege
  need distinct scope names; the override handles it, but the naming convention is undecided.
- **Plugin scope names.** `add_api_key_scope` does not namespace today, so plugin resources
  share one flat namespace and can collide. Defaulting a plugin endpoint's scope resource to
  its Kit namespace would fix it for Kit endpoints.
- **`include` versus scopes.** A key scoped to `queries:read` can `include=user` and receive
  user records, because scopes gate routes and `include` is not a route. Guardian still
  applies row-level, so nothing leaks that the caller couldn't otherwise read. Cheapest
  defensible position: `include` is part of the endpoint's contract, so the endpoint's scope
  covers it — decide before someone asks.

## 9. Publication and support — the `internal` keyword (decided 2026-07-31, unbuilt)

Decided in design review. "Convert everything" plus "documentation is generated from the
declarations" read together imply that *every* endpoint becomes a documented, versioned,
compatibility-promised public contract — a bigger commitment than intended, and one the design
did not previously state either way.

**What framed the decision.** The published reference has never been the whole surface that
integrators actually depend on, and documentation status has not matched stability in either
direction: documented endpoints have changed, and undocumented ones have had dependents. So
the useful distinction is not documented-vs-hidden but **what we promise**, stated explicitly.

**The stance.** Documented, versioned and supported is the **default**. An `internal` keyword
opts an endpoint out: no generated docs, no version obligation, and no mandatory
`Api-Version` header (nothing to pin). The customer-facing contract becomes one sentence: *if
it's in the docs, it's supported; if it isn't, you're on your own.* Intended for endpoints
shaped for our own client — admin dashboard data, registration, honeypot, pageview tracking.

**What `internal` does NOT change:** types stay mandatory, descriptions still exist, the
contract guard still runs, the framework still supplies pagination, errors and scopes. The
keyword removes *publication and the promise*, never the quality bar — otherwise it becomes
the new place to dump endpoints nobody maintains, which is the habit this whole project
exists to break.

**Route grouping.** Internal endpoints sit under one prefix — `internal`, matching the
codebase convention of keeping non-public code under `internal` folders, so the URL and the
code use the same word. The keyword *derives* the prefix rather than being declared twice, so
the boundary is visible in the URL, in logs and in the network tab, not only in the docs.

**Enforcement as a ratchet.** Omitting endpoints from the documentation is not enough on its
own: integrators depend on undocumented endpoints, which is the situation this is meant to
improve. The mechanism under consideration is to make internal routes unreachable with
`Api-Key` authentication (cookie/session only), which turns "we don't promise" into "you
cannot depend on it" — and makes the versioning exemption *provable*, since nothing can pin
what it cannot call. `is_api?` / `is_user_api?` exist on controllers, so the check itself is
trivial. Three consequences to handle before switching it on:

1. **CSRF.** Cookie-authenticated endpoints need `verify_authenticity_token`; the Kit's blanket
   skip (safe for API-key auth, where there is no ambient credential) has to become
   conditional before any endpoint becomes cookie-only.
2. **Where the boundary sits.** Cookie-only also excludes `User-Api-Key`, i.e. user-api-key
   consumers such as mobile clients, not just server-side integrations — and registration or
   pageview tracking are exactly what a mobile client calls. Needs a decision: session only,
   or session plus user API keys?
3. **Flipping an *existing* endpoint to internal is itself a breaking change**, since people
   call those with API keys today. That transition wants the endpoint lifecycle (deprecate →
   meter usage → dated cutover with a teaching error), not a switch. New endpoints can be
   internal from day one for free.

If enforcement lands, scopes for internal endpoints become meaningless (no API key can reach
them), so the scope derivation (§8) should skip them.

**Considered and rejected: a backend-for-the-frontend layer** serving the app privately. It
means a second surface to maintain, and our own client would stop consuming the public API.
Having the app depend on the same endpoints integrators use is the feedback loop that keeps
their quality high, so it's worth keeping.

**Transition rule worth stating in the contract:** internal → public is additive and safe
(start documenting, start honouring pins from that date); public → internal is a breaking
change and needs the lifecycle above.

### Spiked 2026-08-03 — `internal!`, and one consequence worth keeping

Built: `internal!` / `internal?` on the controller, plus a second endpoint in the spike
(`InternalQueriesController`, serving the *same* `QueryResource` at
`/data-explorer/api/internal/queries`) — which is itself the point: publication is a
per-endpoint decision, not a property of a resource. Nine acceptance examples.

What the keyword does, all spec'd: the endpoint serves **without a version header**,
advertises no resolved version, and **ignores a pin** (an old date still gets the latest
shape — there is no promise to keep); it is **absent from the generated document**; and it
grants **no API key scope**. Everything else is untouched — an unknown filter is still a
teaching 400, so the quality bar really is independent of the promise.

**Partial enforcement falls out for free.** With no scope covering it, a *granular* API key
cannot reach an internal endpoint at all (403), while an unscoped key still can. That is a
weaker version of the cookie-only proposal above, achieved without touching authentication —
and it arrives in the right order: new internal endpoints are unreachable by scoped keys from
day one, while the stricter rule can follow once existing consumers have been metered and
deprecated.

**Route derivation — built 2026-08-03.** A `jsonapi_resource` route helper draws an
endpoint from the controller's own declarations, so the routes file names it once:

```ruby
scope "/data-explorer/api", defaults: { format: :json } do
  jsonapi_resource "queries", controller: "…/json_api_kit/queries"
  jsonapi_resource "queries", controller: "…/json_api_kit/internal_queries"
end
```

which draws:

```
GET  /data-explorer/api/queries            GET /data-explorer/api/internal/queries
GET  /data-explorer/api/queries/:id        GET /data-explorer/api/internal/queries/:id
POST /data-explorer/api/queries
```

Two things are derived rather than repeated. The **`internal/` segment** comes from
`internal!` — the routes file never mentions it, so the boundary cannot be declared in one
place and forgotten in the other (both endpoints are even named `"queries"`; only their
publication differs). And the **verbs** come from what the endpoint implements: reads are
always routed because the framework provides them, while `create`/`update`/`destroy` are
routed only when the controller defines them — spec'd by `POST` to the internal endpoint
raising a routing error.

One dev-mode caveat worth knowing: Rails reloads routes when route files change, not when a
controller changes, so flipping `internal!` needs a route file touch or a restart before the
URL follows. CI catches any mismatch, since the derivation is the only thing drawing routes.

This helper is also the seam the docs generator's `endpoints:` map eventually reads from (see
[API docs generation](./api-docs-generation.md) §6, the generalization path): once routes are
drawn from declarations, `paths` and `operations` can be introspected rather than passed in.

Not built, still as designed: the cookie-only enforcement with its CSRF and user-api-key
consequences.
