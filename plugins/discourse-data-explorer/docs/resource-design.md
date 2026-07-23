# JSON:API Kit — Resource Class Design

**Status:** design settled in a pairing session (2026-07-21) and **built the same day**:
`ResourceBase` (22 unit examples) plus the queries migration — `QueryResource`/
`UserResource`/`GroupResource` replaced the Kit serializers and the controller's `jsonapi`
block, with the full suite green throughout (behavior-preserving by construction). Still
open from the plan: types in the contract-guard baseline, the real resource registry.
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
