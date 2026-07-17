# JSON:API Kit — API Docs Generation (research findings)

**Status:** research notes (2026-07-17), decisions pending discussion. Facts below were
verified in-repo and against the live site/repos on this date.
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
| filters, sorts, default sort, includes, page caps, stats | resource DSL config (`jsonapi do … end`) |
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
  it does not know types (`attribute :ran_at, &:last_run_at` is an opaque block). Options,
  combinable: (a) AR column introspection for column-backed attributes; (b) an explicit
  type declaration for block-backed attributes (a small DSL addition); (c) sampling — core
  already auto-derives JSON schemas from live values in its shared examples
  (`schema_for_json_value`), and the same trick could seed schemas from the contract-guard
  baseline. A decision for the design discussion.
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

## 6. Open questions (for the next session)

- Type metadata source: introspection vs declaration vs sampling (or layered: introspect,
  allow override).
- Generator home and shape: a Kit module walking the registry → hash → YAML, exposed as a
  rake task (and possibly a controller for per-site docs).
- Should the spike build a minimal generator increment (queries resource → valid OpenAPI
  3.1 document + a spec validating a live response against a generated schema)?
- Bruno collection / `tojson` compatibility — the tail tooling consumes plain OpenAPI, so
  this should be free; verify when a real document exists.
