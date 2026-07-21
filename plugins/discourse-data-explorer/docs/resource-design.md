# JSON:API Kit — Resource Class Design

**Status:** design settled in a pairing session (2026-07-21); not built. The natural next
spike increment: migrate the queries resource (serializer + controller `jsonapi` block →
one `QueryResource`).
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

Today those declarations are split between the controller's `jsonapi do … end` block
(query surface) and a serializer class (document shape). The resource class is the merge
of the two halves of one concept.

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

## 3. The DSL

```ruby
class QueryResource < JsonApiKit::ResourceBase
  type :queries

  attribute :name, :string, writable: true
  attribute :description, :string, writable: true
  attribute :query, :string, writable: true, description: "The SQL source of the query." do
    object.sql
  end
  attribute :ran_at, :datetime do
    object.last_run_at
  end
  attribute :hidden, :boolean, if: ->(params) { params[:guardian]&.is_admin? }

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
| `attribute name, type, …, &block`                        | serializer                                   | **type (mandatory, positional)**, `writable:` (default false), `description:` |
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
   unindexed-scan surface — decided long ago, unchanged).
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

Endpoint wiring only: `jsonapi_resource QueryResource` (replacing the `jsonapi do … end`
block) and the write actions via `Service::Base` (future DSL:
`create do service Query::Create end`). Execution context is unchanged: blocks are
*declared* on the resource but still `instance_exec`'d in the controller (guardian,
params, current_user) — moving the declaration home does not move the execution context.

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

1. `ResourceBase` with the wrapped keywords (TDD: unit spec on config recording +
   delegation).
2. `QueryResource` replaces `QuerySerializer` + the controller's `jsonapi` block;
   controller becomes `jsonapi_resource QueryResource`. The full suite must stay green
   throughout — the acceptance specs pin the wire contract, so the migration is proven
   behavior-preserving by construction.
3. `UserResource` / `GroupResource` follow; contract-guard baseline regenerated with
   types added.
4. The extension registry's `serializer_for` stand-in becomes a real resource registry
   (already noted as a follow-up).
