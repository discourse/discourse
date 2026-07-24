# JSON:API Kit — API Docs Generation (research findings)

**Status:** research notes (2026-07-17) + decisions from the 2026-07-21 discussion (§7).
Facts were verified in-repo and against the live site/repos/gem sources on those dates.
**References:** [versioning design](./versioning-design.md) · [plugins design](./plugins-design.md).

---

## 1. How docs.discourse.org works today (verified)

- **Authoring**: rswag documentation specs in core (`spec/requests/api/*_spec.rb`) declare
  paths/operations/parameters in a DSL, with **hand-written JSON schemas** per
  request/response (`spec/requests/api/schemas/json/*.json`). A shared example ("a JSON
  endpoint") validates real responses against those schemas via `json_schemer` — docs are
  hand-authored but **test-verified**.
- **Generation**: `rake rswag:specs:swaggerize` (overridden in `lib/tasks/api_docs.rake` to
  glob `plugins/*/spec/requests/api/` with `LOAD_PLUGINS=1`) runs the specs through a
  formatter and emits `openapi/openapi.yaml` — **OpenAPI 3.1.0**, `info.version: "latest"`.
  Plugin adoption is thin: one plugin (discourse-calendar) documents this way today.
- **Publication**: the `discourse/discourse_api_docs` repo owns the tail. A nightly GitHub
  Action (`update_docs.yml`, cron + manual dispatch) checks out core, boots a test
  container, runs swaggerize, converts YAML → JSON (`tojson.js`, plus a Bruno collection
  via `tobruno`), and opens a PR; merging publishes via GitHub Pages (legacy build, `main`
  root, CNAME docs.discourse.org).
- **Rendering**: **Redoc** (standalone bundle from CDN) loading the same-origin
  `openapi.json`. Current spec: 79 paths / 93 operations, tags per area,
  `components.schemas` empty (rswag inlines everything per operation).

## 2. Assessment: the premise inverts for the Kit

rswag is the right strategy **for the current API**: no single source of truth exists, so
the contract is written by hand and guarded by schema validation in specs.

The Kit inverts that premise. The contract already *is* data:

| Contract surface        | Source in the Kit                                          |
| ----------------------- | ---------------------------------------------------------- |
| types, attributes, relationships | serializers (`record_type`, `attributes_to_serialize`, `relationships_to_serialize`) |
| filters, sorts, default sort, includes, page caps, stats | resource class declarations ([resource design](./resource-design.md)) |
| breaking changes + dates + prose descriptions | `VersionChange` classes (renames as data, `description` required) |
| plugin contributions (relationships, namespaced keys, timelines) | extension registry |
| error shapes | teaching 400s, cursor-profile errors, 422 + pointers — all Kit-owned |
| pagination | cursor-pagination profile (typed, spec'd) |

Writing rswag specs for Kit endpoints would re-declare by hand what the registry already
knows — precisely the drift class the whole design eliminates. **Direction: derive OpenAPI
3.1 from the Kit registry with a generator; don't author it.** (OpenAPI 3.1 is full JSON
Schema 2020-12, which suits generated schemas; core is already on 3.1.0.)

## 3. What derivation buys that authoring can't

- **No drift by construction** — same source feeds the API and its docs.
- **Per-version docs**: rename maps are data, so the contract for *any pinned date* is
  computable — the generator can emit the doc for a given `Api-Version` (Stripe-style
  "docs at your pin"). `info.version` becomes the advertised version date, not `"latest"`.
- **A changelog for free**: every `VersionChange` requires a `description`; the registry
  is a ready-made dated changelog section.
- **Per-site docs**: a site's registry knows its installed extensions, so a site could
  serve its own generated document at runtime (e.g. `GET /api/openapi.json`) — bundled
  plugins in the canonical published doc, custom plugins visible only on the sites that
  run them.

## 4. Reuse the tail, replace the head

The `discourse_api_docs` publication pipeline (nightly action → PR → Pages → Redoc) is
generator-agnostic: it copies a YAML file. The Kit generator can emit a **second
document** (e.g. `openapi-jsonapi.yaml`) that rides the same workflow and renders as its
own Redoc page. Keeping it separate from the existing document is deliberate: the new API
has different conventions end to end (mandatory `Api-Version` header, `vnd.api+json`
media type, cursor pagination, JSON:API error objects) — merging the two under one
document's intro prose would confuse both audiences.

## 5. Honest gaps

- **Attribute types are the real missing input.** The serializer knows attribute *names*;
  it does not know types (`attribute :ran_at, &:last_run_at` is an opaque block).
  **RESOLVED 2026-07-21 — mandatory explicit types on the resource; see §7.**
- **Validation shouldn't be lost.** rswag's strength is that docs are exercised by specs.
  Derivation makes *declared* drift impossible, but block-backed values still need a truth
  check: one generic spec per resource validating a real response against the generated
  schema closes the loop (same shape as the existing contract-guard spec).
- **Query-surface description depth**: OpenAPI describes `filter[...]`/`sort` as
  parameters well enough, but their *semantics* (predicate keys like
  `solved-status.unsolved`) live in prose — `description` fields on the DSL declarations
  would carry that (another small DSL addition).
- **Deprecation/removal surfacing**: OpenAPI has `deprecated: true` per operation — maps
  directly onto the `deprecate` keyword; a `removed_endpoint` drops the operation from
  docs generated for pins after its date (and keeps it, marked deprecated, for older
  pins). Falls out of per-version generation.

## 6. Open questions

- ~~Type metadata source~~ — RESOLVED, see §7.
- ~~Should the spike build a minimal generator increment?~~ — BUILT (2026-07-22):
  `JsonApiKit::OpenApiGenerator` derives the queries document from the declarations
  (typed/nullable attribute schemas, relationship linkage by cardinality, the full query
  surface as parameters, request bodies from `Query::Create::Contract` types + validators,
  `info.version` = the advertised date), and the drift-proof loop is executable —
  `spec/requests/…/open_api_document_spec.rb` validates live responses (collection,
  nested includes + stats, strict-400 errors) against the generated schemas with
  `json_schemer`. Spike input is an explicit `endpoints: [{ path:, controller:, create: }]`
  map; the schemas are strict (`additionalProperties: false`), which the loop needs to
  bite. Attributes generate as *nullable* types (a `null: false` declaration can tighten
  this later) — the loop itself forced that call: never-run queries answer `ran_at: null`.
- **The generator's generalization path (documented 2026-07-22).** The spike input
  (`endpoints: [{ path:, controller:, create: }]`) is scaffolding at a deliberate seam;
  the coupling surface is exactly three facts, each with a known resolution:

  1. **Paths and operations ← routes.** `Rails.application.routes` yields verb, path
     template (`{id}`-ready), and action per Kit controller — verified: three lines of
     introspection reproduce the spike's endpoint map exactly. The generator grows one
     operation builder per *routed* action; `update` (PATCH, body shaped like create's)
     and `destroy` (DELETE → 204) are mechanical additions the current shape doesn't
     foreclose.
  2. **Request-body base ← the resource.** Which attributes a write accepts, and their
     types, derive from the `writable:` declarations — their first consumer beyond
     `from_resource`. (§7 chain amended accordingly: the contract is *enrichment*, not
     source.)
  3. **Constraint enrichment ← the contract, linked by one declaration.**
     `required`/`maxLength` still come from validators. The contract↔resource edge
     arrives with `from_resource` (the contract names its resource; a small registry
     inverts the edge) — or, interim, a metadata-only declaration on the controller
     (docs-only; unrelated to the retired outcome-defaulting sugar). Either way, declared
     exactly once.

  End state: the generator **self-assembles** — `BaseController` descendants + routes, no
  arguments. Everything else it reads is already declarations.
- **Emission built (2026-07-22):** `bin/rake data_explorer:json_api_docs` writes
  `openapi-jsonapi.json` (JSON directly — Redoc consumes it; core's YAML→`tojson.js` step
  exists only because rswag emits YAML). The file is **committed** as a contract artifact:
  a freshness spec (`spec/integration/json_api_kit_openapi_document_spec.rb`) fails when
  declarations change without regenerating, so the diff of the document is the review
  surface for every docs change. `openapi-docs.html` next to it renders via Redoc (the
  docs.discourse.org setup) — serve the plugin directory statically to view.
- **Document richness — "Layer 1" built (2026-07-22):** operations carry derived `tags`
  (= humanized type, grouping the sidebar), `summary` ("List queries"), and `operationId`
  (`listQueries`, core's convention); the document embeds `docs/api-intro.md` as
  `info.description` (authentication, the pinning ritual, pagination, errors — API-wide
  *narrative* is the one legitimately authored piece); resources gained a `description`
  keyword (→ schema + tag descriptions) and attributes an `example:` option (→ JSON Schema
  `examples`, which Redoc composes into realistic samples).
- **Live-captured examples built (2026-07-23):** `open_api_examples_spec.rb` performs
  every documented operation against fabricated data and always validates each exchange
  against its generated schema (this also brought show/create responses into the
  validation loop); with `CAPTURE_API_EXAMPLES=1` it records the exchanges into the
  committed `openapi-examples.json`, which the generator embeds as OpenAPI media-type
  `example`s — the right column of the docs shows *real documents*, ids and cursors
  included. Captures are **deterministic** (verified: consecutive runs byte-identical):
  frozen time, explicit fabricated values and timestamps, ids remapped per type in
  first-seen order, cursors replaced by stable placeholders (opaque by contract). A
  freshness guard (`spec/integration/json_api_kit_openapi_examples_spec.rb`) keeps
  committed examples schema-valid forever: values may age, shapes cannot lie. Declared
  `example:` values additionally flow into the request-body property schemas.
- **Per-version documents + version picker built (2026-07-23):** `document_at(version)`
  down-migrates the latest document through the gap — the same transform philosophy as
  responses, applied to the docs. Schemas rename attribute keys back (`sql`,
  `last_run_at`), query-surface parameters follow (`filter[search]`, sort enums,
  `fields[…]` enums, request-body properties + `required`), and captured examples run
  through `VersionPipeline.down` verbatim — converters included, so the 2026-05-01 doc
  shows `"username": "query_master"` where latest shows the array. Two supporting pieces:
  the `down_field_names`/`down_sort_keys`/`down_filter_keys` pipeline family (inverses of
  `up_*`, same precedence mirrored), and the **`old_type:`** option on
  `renamed_attribute` — a shape-changing rename declares its pre-rename wire type, so
  old-version schemas and down-converted examples agree (declared `example:` values are
  down-converted through the rename's own converter — safe because declared examples are
  well-formed latest values). The rake task emits one document per registered version plus
  an `openapi-versions.json` manifest; `openapi-docs.html` gained a Stripe-style version
  picker. All committed and freshness-guarded — deliberately, since **old-version
  documents change over time** (every new change deepens their gap).
- Generator tail still open: publication wiring (second document through the
  `discourse_api_docs` nightly action); **plugin extensions in the documents** — the
  generator consulting the extension registry so registered relationships, namespaced
  filters (`filter[run-stats.stale]`), include namespaces, and extension resource schemas
  are documented, enabling per-site docs (a site's own `GET /api/openapi.json` covering
  its installed plugins); open design question inside it: versioned docs for own-timeline
  extensions (likely: each base-version document shows them at their latest, override
  mechanics staying prose — one document per override combination is combinatorial); the
- **Changelog + deprecations built (2026-07-23):** the document carries a machine-readable
  `x-changelog` (registry changes grouped by version, newest first — future food for the
  docs-site assistant) and a `# Changelog` markdown section appended to
  `info.description`, both derived from the mandatory change descriptions. The
  **`deprecate` keyword** exists (`deprecate :index, on:, link:` on the resource —
  advisory, reversible, per the endpoint-lifecycle design): callers receive RFC 9745
  `Deprecation: @<epoch>` + `Link rel="deprecation"` headers, and the operation gets
  `deprecated: true` in the docs. `removed_endpoint` (pin-gating, teaching 404, metering)
  remains unbuilt.
- Bruno collection / `tojson` compatibility — the tail tooling consumes plain OpenAPI, so
  this should be free; verify when a real document exists.
- ~~The **resource class** design~~ — RESOLVED: designed 2026-07-21, see
  [resource design](./resource-design.md).

## 7. Decisions and design notes (2026-07-21)

**Direction confirmed:** derive the OpenAPI document from the Kit registry; reuse the
existing publication tail (§4) as a second document.

### Types: mandatory explicit declarations on the resource

No AR column introspection — a resource does not always map to an AR model (the plugins
spike's PORO-backed type is a live example). Every attribute declares its type.

**Graphiti precedent (verified from source):** the type is a *required positional
argument* — `attribute :title, :string` — validated at declaration
(`lib/graphiti/resource/dsl.rb:126`, `Errors::TypeNotFound`); no introspection anywhere.
Types are a dry-types registry (`lib/graphiti/types.rb`) with three coercion contexts
(`read` for serialization, `write` for payloads, `params` for query params), they cascade
into auto-derived typed filters, and they flow into `Graphiti::Schema.generate`, whose
output is diffed against a committed baseline that fails on backwards-incompatible changes
(`schema.rb`, `SchemaDiff`) — the same committed-baseline pattern as the Kit's contract
guard, with types included. Two implications adopted: the Kit's contract descriptor should
carry types (a type change *is* a breaking change the guard currently cannot see), and
filter-value coercion can later ride the same declarations (blocks currently receive raw
strings).

### The docs pipeline chain — one owner per link

> **response schema ← resource** (attributes + types) ·
> **request schema ← resource** (`writable:` attributes as the base) **+ contract
> enrichment** (validators → `required`/`maxLength`; the contract itself derives from the
> resource via `from_resource`)

*(Amended 2026-07-22 while documenting the generator's generalization path: the resource
sources the request base directly, the contract enriches. The spike generator still reads
the contract for the base — flip it when the endpoint map is replaced by route
introspection.)*

Services describe *inputs*, so they can never source response schemas (readable-only
attributes appear in no contract), and contracts carry non-resource params too
(`group_ids`) — hence resource-as-source with the service *deriving* from it, not the
reverse. But the contract remains the right source for request-schema **constraints**:
ActiveModel validators are introspectable — `presence` → `required`, `length:
{ maximum: }` → `maxLength`, `inclusion` → `enum`, `attribute … default:` → `default`.

### `from_resource` (core-phase Service::Base extension, sketched)

`params(from_resource: SomeResource)` imports the resource's *writable* attribute
declarations (names + types) into the contract. Notes:

- **Additive**: imported attributes coexist with inline extras (`group_ids` stays declared
  in the service). A full version could import writable *relationships* as
  `<name>_ids, :array` — exactly what `jsonapi_deserialize` produces.
- **Per-action subsetting** (`except:`/`only:`) since create/update writability differs.
- **Shape from the resource; rules from the action.** Validations and
  `before_validation` normalization are never imported — a service is a business action
  and its rules are action-specific.
- **Removes the declaration duplication — not the whole rename cost.** The spike's
  `sql → query` rename required a manual contract edit (`attribute :query, :string`);
  with `from_resource` that declaration follows the resource automatically. Honest limit:
  the service speaks the wire vocabulary throughout, so custom validations,
  `before_validation` normalization, and steps referencing the attribute by name still
  need their own edits on a rename. One duplication point gone, not a free rename.
- Core-phase change (Service::Base lives in core); the spike designs it, not builds it.

### Missing DSL keywords discovered so far

`type` (mandatory, positional), `description` (attributes/filters/sorts — prose semantics
for docs, e.g. predicate filter keys), `writable:` (gates `from_resource` import;
readable-only attributes like `created_at` must not enter write contracts). This is
Graphiti's attribute option set, independently rediscovered — and none of it fits
jsonapi-serializer's DSL, which is the strongest argument yet for the **resource class**
as the declaration home.

### The live-values trick, disposed

Core's shared examples auto-derive JSON-schema snippets from live response values
(`schema_for_json_value`) and print them as copy-pasteable *suggested fixes* in validation
failure messages — repair tooling for hand-written schemas. Derivation removes that
paste-loop; two pieces survive: (a) sampling as a **one-time scaffold** (a rake task
proposing type declarations for existing block-backed attributes from live serialized
values — human-reviewed, then committed as declarations, never a runtime source); (b) the
**validation loop** as a generic spec validating a live response against the *generated*
schema, with failure messages pointing at the declaration to fix rather than a JSON file.
