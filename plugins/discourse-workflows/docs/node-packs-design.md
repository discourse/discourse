# Node packs: importable declarative HTTP action nodes

Status: design, approved for implementation. Written 2026-09-21 against the code in
`plugins/discourse-workflows` at that date. Section 3 lists every seam the design relies
on with the file and behaviour verified; implementers must re-verify a seam before
changing it.

Companion visual concepts (proposals, not implementation): `/tmp/jev-family-mocks/01-import.png`,
`02-palette.png`, `03-choice.png`, `04-batch.png`. Where this document and the mocks disagree,
this document wins; the deltas are called out in section 11.

---

## Implementation amendments (authoritative)

These corrections supersede conflicting details below and must be read by every implementer:

1. **Disable fails closed.** Never reuse skip/pass-through semantics for disabled pack nodes. Registry lookup must retain disabled definitions so the executor can identify them. Add a narrowly scoped executor guard for pack availability that records a node error and prevents downstream execution (including pinned/test paths). Preserve existing Ruby-plugin semantics. Dialog: “Nodes from this pack cannot run until it is re-enabled. Workflows reaching these nodes stop with an error. Requests already in flight cannot be recalled.” Update T-R09/T-R15 accordingly. Hide-from-palette remains execution-neutral.
2. **Pin effective definitions, not just node-local JSON.** Each immutable definition stores the resolved credential schema and the canonical origin of its own static request URL. Changing a pack-level credential or that node's request permission must not silently change an old definition. Retired definitions retain their originally approved request origin while installed; import review must disclose the union of destinations still executable (including retired definitions). Disabling is the immediate revocation mechanism. Hash the complete effective behavior except cosmetic fields such as labels; retain cosmetic values in the immutable snapshot for historical display.
3. **Lifecycle cache isolation.** Cache keys and invalidation are per database and test-safe. In-flight requests cannot be recalled, but each new node execution must honor disabled/removed state even when cached classes exist. Never claim a post-response origin check prevents redirect credential leakage; redirects must be prohibited before following.
4. **Validate responses and untrusted schemas.** Enforce declared output schemas at runtime, without remote $ref fetching, eval, or unbounded recursive schema resolution. Manifest structure/template/JSON-schema limits must prevent resource exhaustion and unsafe object keys. Do not echo arbitrary response bodies or credential values in persisted errors/logs.
5. **Removal/history.** Keep inert immutable definition snapshots (or equivalent immutable audit data) for historical inspection. Removing a pack removes its executable registry availability, not past evidence. A later reinstall cannot overwrite retained behavior at the same identifier/version. Active/current references and pending/running/waiting execution references block removal; history alone does not. Handle install/update/remove races using existing transaction/locking patterns.
6. **Pragmatism and ownership.** Backend owns additional executor guards, tests, and any fields needed to implement these amendments. Frontend owns its node-type service cache invalidation helper if absent. Use the API/UI contract below; if a correction is needed, record it in this document and notify the main agent. Do not implement provider-specific conditional behavior. Batch JSON criteria and existing generic output display are accepted v1 simplifications; the simple Choice/Score/Noul nodes must remain usable through normal form controls.

### Implemented contract and deviations

This section records the integrated implementation truth and supersedes stale implementation
language elsewhere in this document:

- Removal is a soft lifecycle transition. The pack row is marked `removed_at`, all active
  definitions are retired, and immutable definition rows remain as audit evidence. Registry
  availability disappears after invalidation; reinstalling a higher pack revision may only
  un-retire an identical `(identifier, version)` definition. Conflicting retained behavior is
  rejected.
- Disabled imported nodes use a dedicated executor error path before pinned output, test output,
  configuration validation, or node execution. They do not reuse Ruby plugin unavailable-node
  skip/pass-through behavior.
- Effective definitions contain inherited icon/color, the resolved credential slot, and only the
  canonical origin of that node's static request URL. Pack display metadata and credential labels
  are not part of the effective execution hash. Existing definition rows are not rewritten during
  an update. Preview/install approval is the exact union of current manifest destinations and
  origins retained definitions can execute, so this reviewed union may exceed the manifest's
  five-current-destination limit.
- Runtime classes are cached per database behind a per-database Redis stamp. `available?` and
  `palette_visible?` query current pack state, so stale class objects still fail closed before a
  new execution after disable/removal. Every lifecycle API mutation bumps the stamp after its
  database transaction. Output schemas are compiled once per generated runtime class.
- Workflow graph writes, historical restores, persisted AI patches, execution creation, and pack
  lifecycle writes use a shared PostgreSQL transaction advisory lock per pack key. Every graph
  write revalidates exact installed `(identifier, typeVersion)` references after acquiring the
  lock. Removal re-runs the targeted current-draft/active/live-execution usage query while holding
  that lock. The usage query reads the live draft JSON directly, expands only the active version,
  and does not load unrelated historical versions or issue a query per pack node.
- HTTP redirects are not followed. The approved nonempty origin is checked before dispatch; URLs
  containing userinfo and unsafe headers introduced by header authentication fail before dispatch.
  The final URL check is defense in depth only. Pack requests redact non-2xx bodies, and
  output-schema failures do not persist or echo response bodies.
- Pack response schemas are object-only and use a deliberately restricted structural/primitive
  subset: no references, regex/format keywords, conditionals, composition, dependencies, or
  unevaluated keywords. Bounds and scalar enum sizes are capped. A schema describes the object
  actually stored; without a schema, scalar/array outputs are wrapped as `{ "data": value }`.
  Template response paths support bounded non-negative array indexes, invalid traversal resolves
  to `null`, and array omission preserves literal `false`/`null` values.
- `POST /node-packs` returns `201` for install/update and `200` for an unchanged manifest. Remove
  returns `204` while retaining inert audit rows. HTML admin catch-alls and `.json` resource routes
  are separate and covered together by request specs.
- The shipped example's fixed collections use the existing generic configurator. Expressions use
  the existing leading `=` representation (for example `={{ $json.post.raw }}`). Batch criteria
  remain JSON text. Literal manifest copy is escaped; only existing translation-backed rich text
  follows the trusted HTML path.

---

## 1. Scope

### 1.1 Product summary

An admin can import a **node pack**: a declarative JSON manifest that adds one or more
**external HTTP action nodes** to the workflow palette. Importing shows a preview (nodes,
outbound destinations, credential requirements) and requires explicit approval of every
outbound destination. Installed packs can be disabled/re-enabled, hidden from/shown in the
palette, updated to a newer revision, exported, and removed. Nothing in a manifest is
executable code: it describes properties (rendered by the existing property configurator), a
bounded request template, a bounded response template, and a typed output schema.

### 1.2 In scope (v1)

- Manifest format v1 (section 4) and its server-side validator.
- Exactly one node kind: `action` nodes that perform one HTTPS request per input item.
- Pack lifecycle: preview, install, update (new revision), enable/disable, palette hide/show,
  remove, export (section 8, API in section 9).
- Registry/executor integration so pack nodes are first-class node types with exact
  `type`+`typeVersion` pinning (section 7).
- Admin UI: Node packs list, detail (with Used by), import dialog, lifecycle dialogs, palette
  group with pack badge and "Manage packs" link (section 11).
- Editor support for literal (non-i18n) labels/descriptions supplied by a pack (section 10).
- AI authoring catalog discoverability for pack nodes (section 12).
- Example pack: TypeSafe "Jev" with four palette entries (section 5). It is an example only;
  nothing in core code may reference it.

### 1.3 Out of scope (v1, explicitly)

- Triggers, webhooks, conditions/flow nodes, wait/resume nodes, scripts, custom JS UI,
  custom output-schema resolvers, dynamic option loading (`load_options_method`), per-pack
  icons/colours outside the allowlist, non-HTTPS destinations, request URLs or headers
  built from expressions, expression defaults inside manifests, remote pack registries or
  auto-update, per-node version pruning UI, credentials stored in or exported with packs,
  nested collections inside collections (affects the batch example node, see section 14.1).

---

## 2. Vocabulary and identity rules

| Term | Definition |
| --- | --- |
| Pack | One installed manifest. Identified by `key` (`^[a-z][a-z0-9_]{1,31}$`, unique per site). |
| Pack revision | `version` of the manifest, semver `MAJOR.MINOR.PATCH`. Only increases. |
| Node definition | One node inside a pack. Identified by node `key` (`^[a-z][a-z0-9_]{1,39}$`) and node `version` (`^\d+\.\d+$`, e.g. `"1.0"`). |
| Node type identifier | `action:<pack_key>.<node_key>` (e.g. `action:jev.choice`). The `.` separator is reserved for packs; Ruby-registered identifiers never contain `.` (verified: every identifier in `lib/discourse_workflows/nodes`). Ruby nodes remain authoritative: a manifest whose identifier resolves to a Ruby node is rejected (`identifier_reserved`). |
| Retired definition | A (identifier, version) that is still installed and executable but no longer offered in the palette because a newer pack revision changed or dropped it. |
| Destination | An origin (`scheme://host[:port]`, HTTPS only) a pack is allowed to send requests to. Approved explicitly by the admin at install/update time. |

Immutability rule (the "no silent update" rule): the content hash of a node definition is
bound to (identifier, version). A later import that changes a definition's content must bump
that definition's `version`; the old (identifier, version) stays installed and retired.
Workflows pin `typeVersion`, so a published workflow keeps executing the exact definition it
was published with until an admin edits it to the newer version or removes the pack.

---

## 3. Verified seams

| Seam | File | Verified behaviour relied on / change required |
| --- | --- | --- |
| Node class contract | `lib/discourse_workflows/node_type.rb`, `node_type_descriptor.rb` | Classes expose `description`, `identifier`, `version`, `property_schema`, `credentials`, `output_contracts`, `label_key`, `description_key`, `palette_group`, `ui_metadata`, `available?`, `palette_visible?`, `unavailable_reason_key`, `capabilities`, `ports`, `input_ports`, `operations`, `new(**).execute(exec_ctx)`. `NodeType.inherited` appends every subclass to `registered_nodes` (plugin.rb registers all of them at boot; `waiting_identifiers` calls `identifier` on all). Pack classes must be excluded (7.1). `palette_group` does `GROUPS.fetch(group)` — pack group must be provided without touching `GROUPS` (7.1). |
| Registry | `lib/discourse_workflows/registry.rb` | `find_node_type(identifier, version:)` is an exact `[identifier, version]` hash lookup over `DiscoursePluginRegistry` entries, rebuilt on every call (no memo). `available_versions` sorted via `Gem::Version`. Change: consult a second, DB-backed source (7.2). |
| Plugin registration | `lib/discourse_workflows/plugin_node_registration.rb` | Registers Ruby classes by name into `DiscoursePluginRegistry`. Unchanged; packs never enter `DiscoursePluginRegistry`. |
| Serializer | `lib/discourse_workflows/node_type_serializer.rb` | Emits `displayName` (= `label_key`), `ui` (= `ui_metadata`), `versions`, `latest`, `output_contracts`, `palette_visible`, `available`, `metadata`. Change: additive keys (10.1). |
| Node list service | `app/services/discourse_workflows/node_type/list.rb` | Iterates `Registry.nodes.uniq(&:identifier)`; pack classes appear automatically once Registry includes them. |
| Executor lookup | `lib/discourse_workflows/executor.rb:314-329` | Exact lookup by `node.type` + `node.type_version`; unknown class → `handle_unknown_node` (error step "Unknown node type"); unavailable Ruby-plugin nodes retain skip/pass-through semantics. Imported pack nodes take a dedicated fail-closed error path before pinned/test output and downstream execution. |
| Snapshot pinning | `lib/discourse_workflows/workflow_snapshot.rb`, `workflow_graph_validator.rb:162-190` | Graph nodes store `type` + `typeVersion` (default `"1.0"`). Validator rejects `typeVersion` not in `available_versions(include_disabled_plugins: true)`; pack registry must answer with disabled and retired versions for that flag (7.2). `NodeView#numeric_version` does `Float(version)` — node versions must be `MAJOR.MINOR` strings (2). |
| Parameters | `executor/node_execution_context.rb:277`, `executor/parameter_resolver.rb` | `get_node_parameter(path, item_index, default:)` resolves `={{ }}` expressions per item, supports dotted paths into fixed collections (`"headers.values"` → row array). `no_data_expression: true` disables resolution. |
| Credentials | `node_execution_context.rb:291,538-552,613-695` | `get_credentials(slot, item_index)` requires slot declared in `description[:credentials]`, credential id referenced by the node's `credentials` hash and by a `WorkflowDependency(credential_id)` row, and `credential_type` in the slot's `credential_types`. Credential data is never in graph JSON — only `{ id, credential_type }`. |
| HTTP | `executor/http_client.rb`, `nodes/http_request/request_builder.rb`, `authenticator.rb`, `response_parser.rb` | `exec_ctx.http_request(method:, url:, headers:, body:, options:, item_index:)`; Faraday over `FinalDestination::FaradayAdapter` (SSRF-safe DNS/IP resolution; no redirect middleware, so 3xx is returned, not followed — verified `lib/final_destination/faraday_adapter.rb` is a plain `NetHttp` subclass). `Authenticator.apply` reads `config["authentication"]` ∈ `basic_auth|bearer_token|header_auth` and always uses credential slot `"auth"`. Retries: `max_retries` clamped 0..5, `retry_statuses`. Response size via `max_response_size_kb`. 30 s timeouts. Reused unchanged except one additive option (7.4). |
| Output schema | `lib/discourse_workflows/schema.rb:421` | `Schema.normalize` requires `"$schema": "https://json-schema.org/draft/2020-12/schema"` and JSONSchemer validity. Pack `output_schema` goes through it unchanged. Dynamic resolvers are hardcoded (`admin/lib/workflows/node-output-schemas.js` only knows `summarize`) — packs never declare a resolver. |
| Property validator | `lib/discourse_workflows/property_schema_validator.rb` | Whitelists field types/keys/`ui` keys/`type_options` keys. Packs are validated by a stricter subset (4.4) and additionally by this validator. Change: add `label`, `description`, `placeholder` to `KNOWN_FIELD_KEYS` (10.2). |
| Dependencies | `app/models/discourse_workflows/workflow_dependency.rb`, `lib/discourse_workflows/workflow_dependency_indexer.rb` | Rows `(workflow_id, dependency_type: "node_type", dependency_key, node_id, workflow_version_id)` indexed for the draft version on create/update/apply_patch only. Not reliable for historical versions → removal checks scan version JSON (8.4). |
| Executions | `app/models/discourse_workflows/execution.rb:19` | `status` enum `pending 0, running 1, success 2, error 3, waiting 4, rate_limited 5, skipped 6`; column `workflow_version_id`. |
| Frontend node types | `admin/assets/javascripts/admin/lib/workflows/node-types.js` | `nodeTypeLabel` = `i18n(label_key)` (raw key shown if missing); `nodeTypeDescription` = `translatedOrNull`; `nodeTypePaletteGroup` returns `ui.palette_group` and `node-panel.gjs:110` does `i18n(paletteGroup.label_key)`. Change: literal fallbacks (10.3). |
| Frontend property engine | `admin/lib/workflows/property-engine.js:85-140,312-325` | Label/description/placeholder/option-label resolved from i18n keys with `humanizeKey`/`option.label` fallbacks; `Field` renders description via `trustHTML` (`configurators/field.gjs:151-155`). Change: literal fallbacks that are **not** trusted HTML (10.3). |
| Credential slot label | `admin/components/workflows/node/configurator.gjs:46` | `i18n(slot.label_key \|\| "discourse_workflows.credentials.type")`. Change: `slot.label` literal first (10.3). |
| Node types service | `assets/javascripts/discourse/services/workflows-node-types.js` | Caches `/node-types.json` until `clear()`. Pack mutations must call `clear()`. |
| Admin routing | `admin/assets/javascripts/admin/discourse-workflows-route-map.js`, `assets/javascripts/discourse/initializers/admin-plugin-configuration-nav.js`, `config/routes.rb` | Flat sibling routes under `adminPlugins.show` (`discourse-workflows-credentials`, `-data-tables` with `show/:id`), server `get` catch-alls to `admin#index`, JSON routes in the same scope. |
| Credentials admin page | `admin/components/workflows/credential/manager.gjs`, `paginated-list-manager.js`, `admin-table.gjs`, `in-use-dialog.gjs`, `empty-state.gjs` | Reference implementation for the packs list/dialogs. |
| AI catalog | `lib/discourse_workflows/ai/tools/workflow_node_catalog.rb:332-360` | Enumerates `Registry.nodes`; `EXAMPLES` constant hardcoded by identifier. Change: additive (12). |
| Services/controllers | `app/services/discourse_workflows/credential/create.rb`, `app/controllers/discourse_workflows/credentials_controller.rb` | `Service::Base` with `policy :can_manage_workflows`, controllers `< ::Admin::AdminController`, `requires_plugin`, `with_service`-style result blocks, `failed_json`. |

---

## 4. Manifest format v1

A manifest is a JSON object (UTF-8, ≤ 256 KiB). Unknown keys anywhere are rejected
(`unknown_key`), so the format can grow without ambiguity.

### 4.1 Top level

```jsonc
{
  "format": "discourse-workflows/node-pack",  // required, exact
  "format_version": 1,                        // required, exact
  "key": "jev",                               // required, pack key
  "version": "1.0.0",                         // required, semver
  "name": "Jev",                              // required, ≤ 60 chars, plain text
  "description": "…",                         // optional, ≤ 500 chars, plain text
  "homepage": "https://docs.typesafe.ai",     // optional, https URL
  "icon": "wand-magic-sparkles",              // optional, from NodePacks::ICONS allowlist
  "color": "violet",                          // optional, from colors.scss list (see 4.6)
  "destinations": [ { "origin": "https://api.typesafe.ai" } ],  // required, 1..5, https only
  "credentials": [                            // required, 0..3 (v1: nodes may use at most one)
    { "key": "api", "label": "TypeSafe API key", "credential_types": ["bearer_token"], "required": true }
  ],
  "nodes": [ /* 1..20 node definitions, section 4.2 */ ]
}
```

`credential_types` ⊆ identifiers returned by `Registry.credential_types` (today
`basic_auth`, `bearer_token`, `header_auth`). Credentials are site-local records chosen per
node instance in the editor; the manifest only names the slot and the accepted types.

### 4.2 Node definition

```jsonc
{
  "key": "choice",                       // node key → identifier action:jev.choice
  "version": "1.0",                      // MAJOR.MINOR string
  "label": "Choose an option",           // ≤ 80 chars, plain text (palette + configurator title)
  "subtitle": "Choice · One label from a list", // optional ≤ 120, palette second line
  "description": "…",                    // optional ≤ 500, configurator help
  "docs_url": "https://docs.typesafe.ai/primitives/choice", // optional https
  "icon": "list-check", "color": "violet",                 // optional, allowlisted (inherit pack)
  "credential": "api",                   // optional, pack credential key; null = no auth
  "properties": { /* 4.4 */ },
  "request":    { /* 4.3 */ },
  "response":   { /* 4.5 */ },
  "examples":   [ { "name": "…", "parameters": { … } } ]   // optional, ≤ 5, for AI catalog
}
```

Hard limits per node: ≤ 40 properties, property nesting ≤ 3, ≤ 255 static options per
`options` field, template depth ≤ 8, `output_schema` ≤ 32 KiB, examples ≤ 8 KiB total.

### 4.3 `request`

```jsonc
{
  "method": "POST",                                  // GET|POST|PUT|PATCH|DELETE
  "url": "https://api.typesafe.ai/v1/systemone",     // static; origin must be in pack destinations
  "headers": { "Accept": "application/json" },       // static, ≤ 10; forbidden names: authorization, cookie, proxy-*, host, content-length
  "content_type": "json",                            // json only in v1 (body serialised as JSON)
  "body": { /* template, 4.7 */ },                   // optional for GET/DELETE
  "max_request_kb": 256,                             // ≤ 1024
  "max_response_kb": 1024,                           // ≤ 4096
  "retry": { "max": 2, "statuses": [429, 529] }      // max ≤ 3
}
```

Authentication is not expressed in the request: when the node has a `credential`, the
runtime applies the selected credential through the existing `Authenticator` (mode = the
credential's `credential_type`).

### 4.4 `properties`

The value is an existing property schema (the same JSON the serializer already emits for
Ruby nodes), restricted to:

| Key | Allowed |
| --- | --- |
| `type` | `string`, `integer`, `number`, `boolean`, `options`, `multi_options`, `fixed_collection`, `notice` |
| `required`, `default`, `min`, `max`, `max_items` | as today; `default` must not start with `=` (no expression defaults) |
| `options` | array of `"value"` or `{ "value": "…", "label": "…" }` (`label` literal, ≤ 80) |
| `display_options` | `{ "show": { "<field>": [literal values] } }` / `hide`, single level |
| `type_options` | `multiple_values`, `sortable`, `min_required_fields`, `max_allowed_fields` |
| `ui` | `control` ∈ `textarea`, `checkbox`, `select`; `expression` (bool); `format: "json"` (string fields only, see 4.7); `show_label`, `show_description` |
| `label`, `description`, `placeholder` | literal plain text (new keys, see 10.2). `label` ≤ 80, others ≤ 300 |
| `fixed_collection.options` | exactly one group `{ "name": "<group>", "values": { … } }`; nested `values` fields obey this same table minus `fixed_collection` (no collection inside collection, v1) |

Everything else in `PropertySchemaValidator` (`credential`, `custom`, `assignment_collection`,
`collection`, `array`, `object`, `icon`, `load_options_*`, `control_options`, `code`
control, etc.) is rejected for packs. `no_data_expression` is implied for
`options`/`multi_options`/`boolean`/`notice` and forbidden otherwise (expressions are allowed
by default in text fields so admins can map input data, e.g. `state`).

### 4.5 `response`

```jsonc
{
  "output": { /* template, 4.7, using $response */ },   // optional; default = whole body
  "output_schema": { "$schema": "https://json-schema.org/draft/2020-12/schema", "type": "object", "properties": { … } }
}
```

`output_schema` is optional but strongly recommended; it becomes the node's single
`output_contract` (`mode: replace`). If the template refers to `$param`, the schema is still
static: packs describe the shape they promise. In v1 the schema root must be `type: "object"` and
only the restricted structural/primitive keywords listed in the implemented-contract amendments
are accepted. Nodes without a schema may emit any JSON value; non-object values are wrapped under
`data` before workflow storage.

### 4.6 Allowlists (constants in `lib/discourse_workflows/node_packs/limits.rb`)

- `ICONS`: icons the plugin already registers via `register_svg_icon` plus a small set added
  for packs (`list-check`, `gauge`, `circle-question`, `table-cells`, `wand-magic-sparkles`,
  `cloud`, `globe`, `robot`, `scale-balanced`, `tags`). Unknown icon → `icon_not_allowed`.
- `COLORS`: names from `assets/stylesheets/common/colors.scss` (`purple`, `deep-orange`,
  `orange`, `grey`, `indigo`, `teal`, `blue`, `violet`, `red`, `pink`, `green`, `light-blue`,
  `light-green`, `yellow`, `cyan`, `brown`, `salmon`).
- Plain text rule: no control characters other than `\n` in multi-line fields; strings are
  rendered escaped on the client (never `trustHTML`).

### 4.7 Template language (request `body`, response `output`)

A template is JSON. Objects with one of the reserved keys below are placeholders; all other
JSON is emitted literally. Reserved keys never appear in emitted output.

| Placeholder | Meaning |
| --- | --- |
| `{ "$param": "<property path>", "omit_if_blank": true? }` | Resolved node parameter (after expression evaluation, per item). Dotted path allowed (`"options.values"`). `omit_if_blank` drops the enclosing key when the value is `nil`, `""`, `[]`, `{}`. |
| `{ "$rows": "<fixed_collection path>", "key": "<field>", "value": <template> }` | Iterates rows of a fixed collection. With `key` → object keyed by that row field; without `key` → array. Inside `value`, `{ "$row": "<field>", "omit_if_blank": true? }` reads the row field. Duplicate keys → node error `duplicate_row_key`. |
| `{ "$response": "<dot.path>" }` | (response templates only) value at that path in the parsed JSON response; missing → `null`. |
| `"$omit_if_empty": true` (extra key on any object) | After rendering, drop the object if every other key was omitted. |

Property values whose schema declares `ui.format: "json"` are parsed with `JSON.parse`
before substitution (invalid JSON → node error `invalid_json_parameter` naming the field).
This is how a text field can carry structured data without a new control.

Depth ≤ 8, rendered request body ≤ `max_request_kb`. That is the whole language; there are
deliberately no conditionals, string interpolation, or functions. Anything conditional is
expressed by `omit_if_blank`/`$omit_if_empty` or by splitting into separate nodes.

---

## 5. Example pack: `jev` (TypeSafe System One API)

The four palette entries below are the example required by the product brief. They are
data; no Ruby or JS file may special-case `jev`. Request/response shapes follow
<https://docs.typesafe.ai/api>: `POST /v1/systemone`, bearer auth, body `{ state, model,
questions }`, `questions` is a map of `{ type: choice|score|noul, instructions, criteria }`,
answers come back under the same ids; choice answers `{ choice, probabilities, confidence }`,
score answers `{ score, legend, probabilities, confidence }`, noul answers `{ noul }` (no
confidence). Each workflow item is one request; no cross-item batching.

```jsonc
{
  "format": "discourse-workflows/node-pack",
  "format_version": 1,
  "key": "jev",
  "version": "1.0.0",
  "name": "Jev",
  "description": "Typed judgments from the TypeSafe System One API. Sends only the state you map and returns structured answers.",
  "homepage": "https://docs.typesafe.ai",
  "icon": "wand-magic-sparkles",
  "color": "violet",
  "destinations": [{ "origin": "https://api.typesafe.ai" }],
  "credentials": [
    { "key": "api", "label": "TypeSafe API key", "credential_types": ["bearer_token"], "required": true }
  ],
  "nodes": [
    {
      "key": "choice",
      "version": "1.0",
      "label": "Choose an option",
      "subtitle": "Choice · One label from a list",
      "description": "Picks one option from the list you define and returns the chosen option, per-option probabilities and a confidence.",
      "docs_url": "https://docs.typesafe.ai/primitives/choice",
      "icon": "list-check",
      "credential": "api",
      "properties": {
        "model": { "type": "options", "required": true, "default": "jev-latest",
                   "options": ["jev-latest", "jev-1.13.0"], "label": "Model" },
        "state": { "type": "string", "required": true, "ui": { "control": "textarea" },
                   "label": "State", "description": "The content to evaluate. Map a field from the input, e.g. the post body.",
                   "placeholder": "{{ $json.post.raw }}" },
        "question": { "type": "string", "required": true, "label": "Question",
                      "placeholder": "Which team should handle this support request?" },
        "options": { "type": "fixed_collection", "required": true, "label": "Options",
                     "type_options": { "multiple_values": true, "min_required_fields": 2, "max_allowed_fields": 255 },
                     "options": [{ "name": "values", "values": {
                        "key": { "type": "string", "required": true, "label": "Key", "placeholder": "billing" },
                        "description": { "type": "string", "required": false, "label": "Description", "placeholder": "Payments, invoices, refunds" } } }] }
      },
      "request": {
        "method": "POST",
        "url": "https://api.typesafe.ai/v1/systemone",
        "headers": { "Accept": "application/json" },
        "content_type": "json",
        "body": {
          "state": { "$param": "state" },
          "model": { "$param": "model" },
          "questions": { "answer": {
            "type": "choice",
            "instructions": { "$param": "question" },
            "criteria": { "$rows": "options.values", "key": "key", "value": { "$row": "description", "omit_if_blank": true } }
          } }
        },
        "max_request_kb": 256, "max_response_kb": 256,
        "retry": { "max": 2, "statuses": [429, 529] }
      },
      "response": {
        "output": {
          "choice":        { "$response": "answers.answer.choice" },
          "probabilities": { "$response": "answers.answer.probabilities" },
          "confidence":    { "$response": "answers.answer.confidence" },
          "model":         { "$response": "model" },
          "usage":         { "$response": "usage" }
        },
        "output_schema": {
          "$schema": "https://json-schema.org/draft/2020-12/schema", "type": "object",
          "properties": {
            "choice": { "type": "string", "description": "Highest-probability option key" },
            "probabilities": { "type": "object", "additionalProperties": { "type": "number" } },
            "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
            "model": { "type": "string" },
            "usage": { "type": "object", "properties": { "input_tokens": { "type": "integer" }, "output_tokens": { "type": "integer" } } }
          }
        }
      },
      "examples": [{ "name": "Route a support post to a team", "parameters": {
        "model": "jev-latest", "state": "={{ $json.post.raw }}", "question": "Which team should handle this request?",
        "options": { "values": [ { "key": "billing", "description": "Payments, invoices, refunds" }, { "key": "technical", "description": "Bugs, errors, integrations" }, { "key": "other", "description": "None of these" } ] } } }]
    },
    {
      "key": "score", "version": "1.0",
      "label": "Score against a rubric", "subtitle": "Score · A value across defined levels",
      "description": "Rates the state along ordered levels you define (2–10). Returns a fractional score, the legend, per-level probabilities and a confidence.",
      "docs_url": "https://docs.typesafe.ai/primitives/score", "icon": "gauge", "credential": "api",
      "properties": {
        "model": { "type": "options", "required": true, "default": "jev-latest", "options": ["jev-latest", "jev-1.13.0"], "label": "Model" },
        "state": { "type": "string", "required": true, "ui": { "control": "textarea" }, "label": "State", "placeholder": "{{ $json.post.raw }}" },
        "question": { "type": "string", "required": true, "label": "What to rate", "placeholder": "How urgent is this request?" },
        "levels": { "type": "fixed_collection", "required": true, "label": "Levels (lowest first)",
                    "type_options": { "multiple_values": true, "sortable": true, "min_required_fields": 2, "max_allowed_fields": 10 },
                    "options": [{ "name": "values", "values": { "description": { "type": "string", "required": true, "label": "Level description" } } }] }
      },
      "request": { "method": "POST", "url": "https://api.typesafe.ai/v1/systemone", "content_type": "json",
        "body": { "state": { "$param": "state" }, "model": { "$param": "model" },
          "questions": { "answer": { "type": "score", "instructions": { "$param": "question" },
            "criteria": { "$rows": "levels.values", "value": { "$row": "description" } } } } },
        "retry": { "max": 2, "statuses": [429, 529] } },
      "response": {
        "output": { "score": { "$response": "answers.answer.score" }, "legend": { "$response": "answers.answer.legend" },
                    "probabilities": { "$response": "answers.answer.probabilities" }, "confidence": { "$response": "answers.answer.confidence" },
                    "model": { "$response": "model" }, "usage": { "$response": "usage" } },
        "output_schema": { "$schema": "https://json-schema.org/draft/2020-12/schema", "type": "object", "properties": {
          "score": { "type": "number" }, "legend": { "type": "object", "additionalProperties": { "type": "string" } },
          "probabilities": { "type": "object", "additionalProperties": { "type": "number" } },
          "confidence": { "type": "number" }, "model": { "type": "string" }, "usage": { "type": "object" } } }
      }
    },
    {
      "key": "noul", "version": "1.0",
      "label": "Check a statement", "subtitle": "Noul · Probability a statement is true",
      "description": "Returns the probability (0–1) that a yes/no statement is true. There is no separate confidence; set your own threshold in the next node.",
      "docs_url": "https://docs.typesafe.ai/primitives/noul", "icon": "circle-question", "credential": "api",
      "properties": {
        "model": { "type": "options", "required": true, "default": "jev-latest", "options": ["jev-latest", "jev-1.13.0"], "label": "Model" },
        "state": { "type": "string", "required": true, "ui": { "control": "textarea" }, "label": "State", "placeholder": "{{ $json.post.raw }}" },
        "statement": { "type": "string", "required": true, "label": "Statement to check", "placeholder": "The author is asking for a refund." },
        "true_means": { "type": "string", "required": false, "label": "What yes means", "placeholder": "Explicitly asks for money to be returned." },
        "false_means": { "type": "string", "required": false, "label": "What no means", "placeholder": "Mentions billing without requesting money back." }
      },
      "request": { "method": "POST", "url": "https://api.typesafe.ai/v1/systemone", "content_type": "json",
        "body": { "state": { "$param": "state" }, "model": { "$param": "model" },
          "questions": { "answer": { "type": "noul", "instructions": { "$param": "statement" },
            "criteria": { "$omit_if_empty": true, "true": { "$param": "true_means", "omit_if_blank": true }, "false": { "$param": "false_means", "omit_if_blank": true } } } } },
        "retry": { "max": 2, "statuses": [429, 529] } },
      "response": {
        "output": { "noul": { "$response": "answers.answer.noul" }, "model": { "$response": "model" }, "usage": { "$response": "usage" } },
        "output_schema": { "$schema": "https://json-schema.org/draft/2020-12/schema", "type": "object", "properties": {
          "noul": { "type": "number", "minimum": 0, "maximum": 1, "description": "Probability the statement is true" },
          "model": { "type": "string" }, "usage": { "type": "object" } } }
      }
    },
    {
      "key": "batch", "version": "1.0",
      "label": "Evaluate questions", "subtitle": "Batch · Several judgments, one request",
      "description": "Asks several independent choice, score or noul questions about the same state in one request. Answers come back under the question ids you choose.",
      "docs_url": "https://docs.typesafe.ai/api", "icon": "table-cells", "credential": "api",
      "properties": {
        "model": { "type": "options", "required": true, "default": "jev-latest", "options": ["jev-latest", "jev-1.13.0"], "label": "Model" },
        "state": { "type": "string", "required": true, "ui": { "control": "textarea" }, "label": "State", "placeholder": "{{ $json.post.raw }}" },
        "questions": { "type": "fixed_collection", "required": true, "label": "Questions",
          "description": "Each question is evaluated independently against the same state.",
          "type_options": { "multiple_values": true, "min_required_fields": 1, "max_allowed_fields": 50 },
          "options": [{ "name": "values", "values": {
            "id": { "type": "string", "required": true, "label": "Answer id", "placeholder": "department" },
            "type": { "type": "options", "required": true, "default": "noul", "options": [
              { "value": "choice", "label": "Choice" }, { "value": "score", "label": "Score" }, { "value": "noul", "label": "Noul" } ], "label": "Type" },
            "instructions": { "type": "string", "required": true, "ui": { "control": "textarea" }, "label": "Question" },
            "criteria": { "type": "string", "required": false, "ui": { "control": "textarea", "format": "json" }, "label": "Criteria (JSON)",
              "description": "Choice: {\"key\": \"description\"}. Score: [\"level 0\", \"level 1\"]. Noul: {\"true\": \"…\", \"false\": \"…\"} or empty." } } }] }
      },
      "request": { "method": "POST", "url": "https://api.typesafe.ai/v1/systemone", "content_type": "json",
        "body": { "state": { "$param": "state" }, "model": { "$param": "model" },
          "questions": { "$rows": "questions.values", "key": "id", "value": {
            "type": { "$row": "type" }, "instructions": { "$row": "instructions" }, "criteria": { "$row": "criteria", "omit_if_blank": true } } } },
        "retry": { "max": 2, "statuses": [429, 529] } },
      "response": {
        "output": { "answers": { "$response": "answers" }, "model": { "$response": "model" }, "usage": { "$response": "usage" } },
        "output_schema": { "$schema": "https://json-schema.org/draft/2020-12/schema", "type": "object", "properties": {
          "answers": { "type": "object", "description": "One answer per question id", "additionalProperties": { "type": "object", "properties": {
            "type": { "type": "string" }, "choice": { "type": "string" }, "score": { "type": "number" }, "noul": { "type": "number" },
            "probabilities": { "type": "object" }, "legend": { "type": "object" }, "confidence": { "type": "number" } } } },
          "model": { "type": "string" }, "usage": { "type": "object" } } }
      }
    }
  ]
}
```

Ship this file as `plugins/discourse-workflows/docs/examples/node-packs/jev.json` (used by
specs and manual QA; not auto-installed). Palette result: group **Jev** with four entries
whose labels/subtitles match the mocks; node output `$json.choice`, `$json.score`,
`$json.noul`, `$json.answers.<id>.…` are visible as typed fields in the output column.

---

## 6. Data model

Two tables (plugin migration generated with
`bin/rails g plugin_migration CreateWorkflowNodePacks --plugin-name=discourse-workflows`;
no foreign keys, no seed rows, both in `db/migrate`):

```ruby
create_table :discourse_workflows_node_packs do |t|
  t.string  :key,             null: false, limit: 32
  t.string  :name,            null: false, limit: 60
  t.string  :version,         null: false, limit: 32        # installed pack revision
  t.jsonb   :manifest,        null: false                    # normalized manifest as installed
  t.string  :manifest_sha256, null: false, limit: 64
  t.jsonb   :approved_destinations, null: false, default: [] # ["https://api.typesafe.ai"]
  t.boolean :enabled,         null: false, default: true
  t.boolean :palette_visible, null: false, default: true
  t.integer :installed_by_id, null: false
  t.integer :updated_by_id
  t.timestamps
end
add_index :discourse_workflows_node_packs, :key, unique: true

create_table :discourse_workflows_node_pack_definitions do |t|
  t.bigint  :node_pack_id,      null: false
  t.string  :identifier,        null: false, limit: 100     # action:jev.choice
  t.string  :version,           null: false, limit: 16      # "1.0"
  t.jsonb   :definition,        null: false                 # normalized node definition (4.2)
  t.string  :definition_sha256, null: false, limit: 64
  t.string  :introduced_in,     null: false, limit: 32      # pack revision that added it
  t.datetime :retired_at
  t.timestamps
end
add_index :discourse_workflows_node_pack_definitions, %i[identifier version], unique: true
add_index :discourse_workflows_node_pack_definitions, :node_pack_id
```

Models: `DiscourseWorkflows::NodePack` (`has_many :definitions`, validations mirror 4.x
limits as a safety net, `scope :enabled`) and `DiscourseWorkflows::NodePackDefinition`
(`belongs_to :node_pack`, `scope :active, -> { where(retired_at: nil) }`). Add
`DiscourseWorkflows::WorkflowDependency::TYPES` unchanged (`node_type` rows already exist
for every node; nothing new to index).

`definition_sha256` = SHA-256 of the canonical JSON (sorted keys, no whitespace) of the
normalized node definition **excluding** `examples`, `subtitle`, `description`, `docs_url`,
`icon`, `color` and property `label`/`description`/`placeholder` — cosmetic text may change
without a version bump; anything affecting properties' shape, request or response must bump.
`manifest_sha256` covers the whole normalized manifest and drives idempotency.

Cache stamp: `DiscourseWorkflows::NodePacks::Runtime.version` is a per-site Redis integer
bumped by every pack mutation (`Discourse.redis.incr`); processes rebuild their synthesized
class cache when it changes. Use `DistributedCache` semantics equivalent (`Discourse.cache`
is not multisite-safe by itself; key must include `RailsMultisite::ConnectionManagement.current_db`).

---

## 7. Runtime integration

### 7.1 Synthesized node classes (`lib/discourse_workflows/node_packs/declarative_node.rb`)

`DeclarativeNode < NodeType` is abstract and never registered:

```ruby
class DeclarativeNode < NodeType
  def self.inherited(subclass)
    super
    NodeType.registered_nodes.delete(subclass)   # pack classes are DB-backed, not plugin-registered
  end
  # … class body …
end
NodeType.registered_nodes.delete(DeclarativeNode)
```

`NodePacks::ClassFactory.build(definition_record, pack_record)` returns
`Class.new(DeclarativeNode)` with:

- `description(name:, version:, defaults: { icon:, color: }, capabilities: { run_scope: "per_item" }, properties:, credentials:, output_contracts: [{ schema: output_schema }], palette_visible: -> { pack.palette_visible && !retired }, available: -> { pack.enabled }, unavailable_reason_key: "discourse_workflows.node_packs.pack_disabled", previewable: false)`.
  `credentials` is `[{ name: "auth", credential_types: [...], required: true, label: "<slot label literal>" }]` when the node declares a credential (slot is always `auth` because `Authenticator` hardcodes it).
- `label_key`/`description_key` return `nil`-safe keys that will not exist; `ui_metadata`
  is overridden to add `label`, `description`, `subtitle`, `docs_url`, and
  `palette_group: { id: "pack:<key>", label: pack.name, icon: pack.icon || "cubes", order: 200 + pack.id }`,
  plus `pack: { id, key, name, version, definition_version, retired }`. `group` returns
  `"pack:<key>"` and `palette_group` bypasses `GROUPS.fetch`.
- `self.pack_definition` (frozen definition hash), `self.pack` (pack record snapshot),
  `self.examples`.
- `self.validate_configuration(parameters, errors)`: `ui.format: "json"` fields must be
  valid JSON or an expression; unknown parameter keys are ignored (existing behaviour).
- `#execute(exec_ctx)` (7.3).

The Runtime memoizes synthesized classes per database and runtime version stamp. Class
availability and palette visibility deliberately query the current pack row, so a class object
already held by an executor cannot bypass a later disable or removal.

### 7.2 Registry changes (`lib/discourse_workflows/registry.rb`)

- `nodes(include_disabled_plugins:)` → `ruby_nodes + NodePacks::Runtime.node_classes(include_disabled: include_disabled_plugins)`.
  `include_disabled_plugins: true` also includes disabled packs and retired definitions
  (graph validation and executor need them); `false` includes enabled packs' definitions
  including retired ones (retired must remain executable) — palette filtering is done by
  `palette_visible?`, not by the registry.
- `find_node_type`: Ruby index first (authoritative), then pack index. Because identifiers
  are namespaced, a duplicate can only arise from a bug; raise `ArgumentError` like today.
- `available_versions`/`latest_version` unchanged in signature; they simply see pack classes.
- `Registry.reset_indexes!` also clears the pack class cache.
- `NodePacks::Runtime.node_classes` loads `NodePack.includes(:definitions)` once per version
  stamp per process (`@cache = { stamp:, classes: }`).

`NodeType::List` and `NodeTypeSerializer` need no logic change; `NodeTypeSerializer`
gains additive keys (10.1).

### 7.3 Execution (`DeclarativeNode#execute`)

```
input_items.flat_map.with_index do |item, item_index|
  params   = resolve_parameters(exec_ctx, item_index)          # get_node_parameter per declared property, json-format parse
  body     = TemplateRenderer.render(request.body, params:)    # 4.7; raises NodeError on limit/duplicate key
  response = exec_ctx.http_request(method:, url: request.url, headers: request.headers, body:, item_index:,
               options: { "authentication" => auth_mode, "max_retries" => retry.max, "retry_statuses" => retry.statuses,
                          "max_response_size_kb" => max_response_kb, "never_error" => false, "allowed_origins" => pack.approved_destinations })
  output   = TemplateRenderer.render(response.output, response: response.body)
  [wrap(output, paired_item: exec_ctx.paired_item_for(item))]
end
```

- `auth_mode` = `exec_ctx.get_node.credentials["auth"]["credential_type"]` when the node
  declares a credential; the executor's `fetch_credentials` already rejects undeclared
  slots, unreferenced ids and disallowed types. If the credential is missing → `NodeError`
  `credential_required` (NodeIssues does not cover credential slots; see test T-R12).
- Output is always a single item per input item; non-object `output` → `{ "data": value }`
  (mirrors `HttpRequest::V1#wrap_response_body`).
- Non-2xx (including 3xx, which the adapter does not follow) → existing `HttpClient`
  node error with truncated body description. `never_error` is not exposed in v1.
- Logging: `HttpClient` already redacts auth headers and omits bodies.

### 7.4 Origin enforcement (additive `HttpClient` option)

`HttpClient#request` accepts `options["allowed_origins"]` (array of origins). When present,
`RequestBuilder` output URI must match one origin exactly (scheme+host+port) **and**, after
the request, `response.env.url` (Faraday's final URL) must match too; otherwise raise
`NodeError` `destination_not_approved`. This is defence in depth on top of the import-time
check (the URL is static) and FinalDestination's IP rules. `never_error` does not suppress it.

### 7.5 Disabled / retired / removed behaviour (executor)

| State | `find_node_type` | Executor | Editor |
| --- | --- | --- | --- |
| Enabled, palette-visible | class | executes | in palette, configurable |
| Palette hidden | class (`palette_visible? = false`) | executes | not in palette; existing nodes configurable |
| Retired definition | class (`palette_visible? = false`) | executes | existing nodes configurable; version badge shows "retired" |
| Pack disabled | class (`available? = false`) | dedicated pack guard records an error and stops; pinned/test output and downstream nodes do not run | node shows the existing "unavailable" treatment |
| Pack removed | `nil` after invalidation; a stale held class reports unavailable | unknown/pack-unavailable error, never pass-through | graph validation fails on save/restore with `unsupported_node_version`; palette entry gone |

---

## 8. Lifecycle

### 8.1 States

Pack: `enabled` × `palette_visible` (booleans); definitions: active/retired. Transitions are
all synchronous admin actions logged with `StaffActionLogger#log_custom`
(`discourse_workflows_node_pack_installed|updated|enabled|disabled|removed`, subject = key).

### 8.2 Preview (never persists, never sends requests)

`NodePacks::Manifest::Parse` (plain Ruby, not a service) → normalized manifest + errors.
`NodePack::Preview` service: policy `can_manage_workflows`, contract `manifest` (string ≤ 256 KiB
or object), step `parse`, step `diff_against_installed`. Output (9.2) includes per-node
change classification: `new`, `unchanged`, `changed` (hash differs, version bumped), `conflict`
(hash differs, version not bumped), `dropped` (installed active, missing in manifest).

### 8.3 Install / update (`NodePack::Install` service, single endpoint)

Contract: `manifest`, `approved_destinations: [origins]`. Steps, in order:

1. `parse_manifest` (fail → `invalid_manifest` with error list).
2. policy `destinations_approved`: every manifest destination ∈ `approved_destinations` (exact origin string match). Fail → 422 `destinations_not_approved`.
3. `lock(:pack_key)` → `model :existing_pack` (optional) → `transaction`:
   - No existing pack → create pack + definitions (`introduced_in = version`). Result `installed`.
   - Existing, same `version`, same `manifest_sha256` → no-op, result `unchanged` (HTTP 200).
   - Existing, same `version`, different hash → fail `revision_conflict` (409). The admin must bump the pack version.
   - Existing, lower `version` → fail `downgrade_not_allowed` (409).
   - Existing, higher `version`: for every manifest node: if `(identifier, version)` exists with same `definition_sha256` → keep; exists with different hash → fail `definition_conflict` (409, lists nodes); new → insert. Definitions present in DB but absent from the manifest → `retired_at = now`. Definitions absent-then-present again with identical hash → un-retire. Update pack row (`version`, `manifest`, hashes, `approved_destinations` replaced, cosmetic fields). Result `updated`.
4. `bump_runtime_version`, `log_staff_action` (outside transaction).

Approved destinations replace, never merge: a new revision that adds a destination requires
re-approval of the full list (the UI pre-checks previously approved ones).

### 8.4 Remove (`NodePack::Remove`)

Blocked (409 `node_pack_in_use`) when any of:

1. A workflow's **current draft** (`workflows.version_id`) or **active/published** version
   (`workflows.active_version_id`) contains a node whose `type` is any identifier of the
   pack. Query (exact, index-free, workflows are few):
   ```sql
   SELECT DISTINCT w.id, w.name, (v.version_id = w.active_version_id) AS published
   FROM discourse_workflows_workflows w
   JOIN discourse_workflows_workflow_versions v
     ON v.workflow_id = w.id AND v.version_id IN (w.version_id, w.active_version_id)
   JOIN LATERAL jsonb_array_elements(v.nodes) n ON TRUE
   WHERE n->>'type' = ANY(:identifiers)
   ```
2. An execution with status `pending|running|waiting` whose `workflow_version_id` version
   contains such a node (same lateral join over `discourse_workflows_executions e JOIN versions v ON v.version_id = e.workflow_version_id`).

Historical versions (neither current nor active, no live execution) never block. Response
lists `referencing_workflows: [{ id, name, published }]` and `active_executions: n` so the
existing `InUseDialog` can render links. The targeted SQL expands only current/active version
rows; it does not preload workflow history. A shared per-pack transaction advisory lock orders
workflow graph writes against install/update/remove, and usage is rechecked while that lock is
held. When unblocked, mark the pack removed and retire active definitions in one transaction;
definition snapshots remain inert for audit and reinstall conflict checks. Bump the runtime
version and log after commit. Credentials, executions, execution data, and historical workflow
versions are untouched. Restoring a historical version that references removed nodes fails graph
validation (`unsupported_node_version`) — nothing is resurrected silently.

### 8.5 Enable / disable / palette (`NodePack::Update`)

Contract `enabled?`, `palette_visible?` (either optional). Disable requires no dependency
check. New executions that reach one of its nodes fail at that node before pinned/test output or
downstream execution. Both transitions bump the runtime version.

### 8.6 Export

`GET /node-packs/:id/export` returns the stored normalized manifest (`Content-Disposition:
attachment; filename="<key>-<version>.json"`). It contains no credential data by
construction (credentials are never part of the manifest schema).

---

## 9. HTTP API contract

All routes live in `config/routes.rb` inside the existing
`scope "/admin/plugins/discourse-workflows"` (admin constraint, JSON format), controller
`DiscourseWorkflows::NodePacksController < ::Admin::AdminController` with `requires_plugin`.
Server-rendered catch-alls: `get "/node-packs" => "admin#index"`, `get "/node-packs/:id"`.

| Method & path | Service | Success | Failures |
| --- | --- | --- | --- |
| `GET /node-packs.json` | `NodePack::List` | 200 `{ node_packs: [PackSummary], meta: { total_rows } }` | 403 |
| `GET /node-packs/:id.json` | `NodePack::Show` | 200 `{ node_pack: PackDetail }` | 404 |
| `POST /node-packs/preview.json` | `NodePack::Preview` | 200 `{ preview: Preview }` | 422 `{ type: "invalid_manifest", errors: [ManifestError] }` |
| `POST /node-packs.json` | `NodePack::Install` | 201 `{ node_pack: PackDetail, result: "installed"\|"updated" }` / 200 `{ …, result: "unchanged" }` | 422 `invalid_manifest`, 422 `destinations_not_approved` `{ missing: [origin] }`, 409 `revision_conflict`, 409 `downgrade_not_allowed` `{ installed_version }`, 409 `definition_conflict` `{ nodes: [identifier] }` |
| `PUT /node-packs/:id.json` | `NodePack::Update` | 200 `{ node_pack: PackDetail }` | 404, 400 contract |
| `DELETE /node-packs/:id.json` | `NodePack::Remove` | 204 | 409 `{ type: "node_pack_in_use", referencing_workflows: [{ id, name, published }], active_executions: n }` |
| `GET /node-packs/:id/export.json` | `NodePack::Show` | 200 manifest JSON (attachment) | 404 |

Error envelope follows `failed_json.merge(errors: [...], type: "...")` as the credentials
controller does; the frontend branches on `type`.

### 9.1 Payload shapes

```ts
type PackSummary = {
  id: number; key: string; name: string; version: string; description: string | null;
  icon: string | null; color: string | null; enabled: boolean; palette_visible: boolean;
  node_count: number;            // active definitions
  retired_count: number;
  used_by_count: number;         // workflows from the 8.4 query
  destinations: string[];        // approved origins
  installed_by: { id, username } | null; updated_at: string;
};

type PackDetail = PackSummary & {
  homepage: string | null;
  credentials: { key: string; label: string; credential_types: string[]; required: boolean }[];
  nodes: {
    identifier: string; key: string; version: string; label: string; subtitle: string | null;
    description: string | null; docs_url: string | null; icon: string | null; color: string | null;
    credential: string | null; retired: boolean; introduced_in: string;
    request: { method: string; url: string };     // summary only
    used_by_count: number;
  }[];
  used_by: { id: number; name: string; published: boolean; node_ids: string[] }[];
  removal: { blocked: boolean; active_executions: number };
};

type ManifestError = { path: string; code: string; message: string };   // path like "nodes[2].properties.state.default"

type Preview = {
  manifest: { key; name; version; description; homepage; icon; color };
  destinations: string[];
  credentials: PackDetail["credentials"];
  nodes: (PackDetail["nodes"][number] & { change: "new" | "unchanged" | "changed" | "conflict" | "dropped" })[];
  installed: { id; version; enabled } | null;
  change: "install" | "unchanged" | "update" | "revision_conflict" | "downgrade" | "definition_conflict";
  previously_approved_destinations: string[];
  warnings: string[];            // e.g. "Node action:jev.batch is dropped; existing workflows keep the retired version"
};
```

`message` strings are server-translated (`server.en.yml` under
`discourse_workflows.node_packs.errors.*`); `code` is stable for tests.

### 9.2 Validation error codes (server)

`unknown_key`, `missing_key`, `invalid_type`, `too_long`, `too_many`, `invalid_format`
(regex), `identifier_reserved`, `duplicate_node_key`, `destination_not_https`,
`url_not_in_destinations`, `header_forbidden`, `credential_unknown` (node references a
credential key not declared), `credential_type_unknown`, `property_type_not_allowed`,
`property_key_not_allowed`, `expression_default_forbidden`, `nested_collection_forbidden`,
`template_reserved_key_misuse`, `template_unknown_param`, `template_depth_exceeded`,
`template_rows_not_collection`, `output_schema_invalid`, `icon_not_allowed`,
`color_not_allowed`, `plain_text_required`, `version_format` (node `MAJOR.MINOR` / pack semver).

---

## 10. Node types contract for the editor (`/node-types.json`)

### 10.1 Additive serializer keys (Ruby nodes unaffected: keys absent)

```jsonc
{
  "name": "action:jev.choice", "version": "1.0",
  "ui": {
    "icon": "list-check", "color": "violet",
    "label": "Choose an option",                  // literal; label_key still present but untranslatable
    "description": "Picks one option …",          // literal
    "subtitle": "Choice · One label from a list", // literal
    "docs_url": "https://docs.typesafe.ai/primitives/choice",
    "palette_group": { "id": "pack:jev", "label": "Jev", "icon": "wand-magic-sparkles", "order": 207 },
    "pack": { "id": 7, "key": "jev", "name": "Jev", "version": "1.0.0", "definition_version": "1.0", "retired": false }
  },
  "credentials": [ { "name": "auth", "credential_types": ["bearer_token"], "required": true, "label": "TypeSafe API key" } ],
  "properties": { "state": { "type": "string", "required": true, "ui": { "control": "textarea" }, "label": "State", "description": "…", "placeholder": "{{ $json.post.raw }}" }, … },
  "output_contracts": [ { "schema": { … }, "mode": "replace", "display_options": {}, "variants": [], "extensions": [] } ],
  "palette_visible": true, "available": true,
  "examples": [ … ]                                  // only when the definition has them
}
```

`versions` includes retired definitions (each with `ui.pack.retired: true`); `latest` is
the highest version as today (a retired-only node has `palette_visible: false`).

### 10.2 Backend property-schema change

`PropertySchemaValidator::KNOWN_FIELD_KEYS += %i[label description placeholder]` and
option entries may carry `label`. These are generic, mechanism-level keys (also usable by
Ruby nodes) — nothing pack-specific.

### 10.3 Frontend literal fallbacks (all in `admin/assets/javascripts/admin/lib/workflows/`)

| Function | New resolution order |
| --- | --- |
| `nodeTypeLabel` (`node-types.js`) | `ui.label` literal → `i18n(label_key)` |
| `nodeTypeDescription` | `ui.description` literal → `translatedOrNull(description_key)` |
| new `nodeTypeSubtitle`, `nodeTypeDocsUrl`, `nodeTypePack` | read `ui.subtitle`, `ui.docs_url`, `ui.pack` |
| `nodeTypePaletteGroup` consumers (`node-panel.gjs:110`) | `group.label` literal → `i18n(group.label_key)` |
| `propertyLabel` (`property-engine.js`) | i18n chain → `schema.label` → `humanizeKey` |
| `propertyDescription` | i18n chain (trusted HTML, unchanged) → `schema.description` **as plain text** (`Field` must render literal descriptions escaped; add `propertyDescriptionIsLiteral` or return `{ text, html }`) |
| `propertyPlaceholder` | i18n chain → `schema.placeholder` |
| `propertyOptionLabel` | already falls back to `option.label` |
| `credentialSlotLabel` (`configurator.gjs`) | `slot.label` literal → existing |

Security invariant: any literal coming from `ui.*`/`schema.*` is rendered through `{{ }}`
escaping only. QUnit test T-F03 asserts a `<img onerror>` label renders as text.

---

## 11. Frontend design

### 11.1 Routes and navigation

- Route map: `this.route("discourse-workflows-node-packs", { path: "node-packs" }, function () { this.route("show", { path: "/:id" }); });`
- Nav initializer: add `{ label: "discourse_workflows.node_packs.title", route: "adminPlugins.show.discourse-workflows-node-packs" }` after Credentials.
- Route files mirror data-tables (`routes/admin-plugins/show/discourse-workflows-node-packs.js`, `…/show.js`), templates mirror `discourse-workflows-data-tables/{index,show}.gjs` with `DBreadcrumbsItem` + `admin-config-page__main-area`.

### 11.2 Node packs list (`components/workflows/node-pack/manager.gjs`)

Extends `PaginatedListManager` (`collectionKey: "node_packs"`, `basePath: …/node-packs`)
and renders `AdminTable` like credentials: columns Name (icon + name, key under it),
Version, Nodes (`n active · m retired`), Used by (count; link to detail), Status
(`enabled`/`disabled` + `hidden from palette` badge), Updated; row actions: `View`, menu with
Enable/Disable, Show/Hide in palette, Export, Remove. Toolbar: `Import pack` (primary).
Empty state uses `EmptyState` (`emoji: "package"`, `buttonLabel: node_packs.import`).

### 11.3 Detail (`node-pack/detail.gjs`, route `show`)

`DPageSubheader` with pack name + `v1.0.0` badge + description + homepage link; actions
Enable/Disable, Show/Hide in palette, Export, Remove. Sections (`AdminConfigAreaCard`):

1. **Nodes** — `d-table`: label (subtitle under it), identifier + version, request (`POST api.typesafe.ai/v1/systemone`), credential, used by count, `retired` badge. Row link "Add to workflow" is out of scope; instead a top notice links to workflows index.
2. **Destinations** — approved origins list.
3. **Credentials** — slot label + accepted types + link to the Credentials page (`New credential` opens existing `CredentialModal`).
4. **Used by** — workflows table (name link to editor, draft/published badge, node count). Fed by `used_by`.

### 11.4 Import dialog (`node-pack/import-modal.gjs`, `DModal`)

Step 1 *Choose*: `Form` (FormKit) with a file input (`.json`) or textarea paste; `Preview`
button → `POST preview`. Errors render as a list (`path — message`).
Step 2 *Review* (mock 01): pack header (name, version, node count, "Declarative HTTP"), node
cards (label + subtitle, change badge on updates), "What this pack can do" inset
(`AdminConfigAreaCard` notice: "Sends the data you map to <origins> and returns typed answers.
No custom executable code. Importing does not send any forum content."), credentials
required list with `New credential` (opens `CredentialModal`; nothing is stored on the
pack), destinations checklist — one `DFormKit.CheckboxGroup` item per origin, all required
to proceed (pre-checked when previously approved). Primary `Install n nodes` / `Update to
1.1.0` → `POST /node-packs`; on 409/422 show the typed message inline. On success:
`workflowsNodeTypes.clear()`, toast, transition to detail.

Delta from mock 01: no pack-level credential binding ("Reused by all four nodes" is not
stored); credentials are chosen per node instance in the configurator, which already offers
"New credential". The dialog runs from the Node packs page (and from the palette link), not
from inside a workflow.

### 11.5 Lifecycle dialogs (`dialog` service)

- Disable: confirm with copy "Nodes from this pack cannot run until it is re-enabled.
  Workflows reaching these nodes stop with an error. Requests already in flight cannot be
  recalled."
- Hide from palette: plain confirm; explains existing nodes keep working.
- Remove: `deleteConfirm`; on 409 use `InUseDialog` with `referencing_workflows` and an
  additional line for `active_executions` when > 0.

### 11.6 Palette (mock 02)

`node-panel.gjs`: pack groups appear as categories after the built-in ones (order 200+).
Inside a pack category: header row with pack name and badge `Imported · v1.0.0`
(`ui.pack.version`), entries render `label` + `subtitle` (subtitle replaces description when
present). Footer of a pack category: link "Manage packs" → node packs route, and
"Import another…" → node packs route with `?import=1` which opens the import dialog. Search
matches label, subtitle and pack name.

### 11.7 Configurator (mocks 03/04)

No new controls. The three-column `configurator.gjs` renders pack nodes through the property
engine: credential slot first (already rendered at the top from `credentials`), then
properties in manifest order (`model`, `state`, …). Header subtitle shows `Jev / Choose an
option` and badge `Imported · v1.0` (from `ui.pack`), with a `Documentation ↗` link from
`ui.docs_url`. Output column shows the typed schema from `output_contracts` (existing
`context/output.gjs`); execution results use the existing generic result/JSON views — no
provider-specific result rendering (mock 03's probability bars are not built).

Mock 04 delta: the batch node edits criteria as JSON text (section 14.1), not with per-type
expanding sub-forms.

### 11.8 Translations (`client.en.yml` under `discourse_workflows.node_packs`)

`title`, `import`, `import_title`, `preview`, `install`, `update_to`, `unchanged`,
`nodes_count`, `used_by`, `status`, `enabled`, `disabled`, `palette_hidden`, `retired`,
`destinations`, `approve_destination`, `what_it_can_do`, `no_custom_code`, `disable_confirm`,
`hide_confirm`, `remove_confirm`, `in_use_title`, `in_use_description`,
`active_executions_blocking`, `manage_packs`, `import_another`, `imported_badge` (`"Imported · v%{version}"`),
`empty_title`, `empty_description`, `pack_disabled` (node unavailable reason). Server:
`discourse_workflows.node_packs.errors.<code>`.

---

## 12. AI catalog discoverability

`WorkflowNodeCatalog#serialize_node`: add `label`, `description`, `subtitle`, `pack` (from
`ui_metadata`) and `examples: EXAMPLES[identifier] || node_class.examples` (pack examples
from the manifest, already bounded). `haystack` gains `label`, `subtitle` and pack name so
"jev" or "choose an option" matches. `GraphDigest` needs no change (uses identifiers).

---

## 13. Security and risk controls

| Risk | Control |
| --- | --- |
| Arbitrary code | Manifest is data only; templates have no evaluation semantics (4.7). Expression defaults rejected. |
| Admin-only | Every service uses `policy :can_manage_workflows`; controller is `Admin::AdminController` behind `AdminConstraint`. |
| Secrets | Manifest schema has no place for secrets; credentials are separate records; `get_credentials` access rules unchanged; export is the stored manifest. Headers named `authorization`/`cookie`/`proxy-*` rejected at import. |
| SSRF / redirect | Destinations HTTPS-only; static URL must be under an approved origin; `FinalDestination` adapter resolves DNS and blocks private ranges; 3xx not followed; 7.4 rejects any final URL outside approved origins. |
| Data exfiltration scope | Only mapped parameters are sent (template must reference params explicitly); UI copy states it. |
| Resource abuse | Manifest ≤ 256 KiB; ≤ 20 nodes; property/template depth limits; request ≤ `max_request_kb`; response ≤ `max_response_kb` (existing parser); retries ≤ 3 with existing 30 s timeouts; existing execution rate limits apply. |
| XSS via literals | Server: plain-text validation; client: escaped rendering only, no `trustHTML` for literals (T-F03). |
| Impersonating core nodes | `.`-namespaced identifiers; Ruby index consulted first; pack palette groups cannot use built-in group ids. |
| Silent behaviour change | Content hash bound to (identifier, version); conflicts rejected; retired definitions keep executing pinned versions. |
| Removal safety | 8.4 blocks on current/active versions and live executions; historical versions never block; removed nodes fail closed. |
| Multisite | Tables per site; runtime version stamp keyed per db. |
| Import never executes | Preview/Install perform no HTTP requests (spec T-R05 asserts `WebMock` sees none). |

---

## 14. Hardest trade-offs, settled

### 14.1 Batch node fidelity vs. nested collections
Mock 04 shows per-question type-specific sub-forms (options list inside a question). That
needs `fixed_collection` inside `fixed_collection`, which the frontend `FixedCollection`
component and `NodeIssues` have not been verified to support, and a per-row conditional
template (`$row_template_by`). Decision: v1 forbids nested collections; the batch example
uses a JSON-formatted text criteria field parsed via `ui.format: "json"`. The three
single-question nodes give the plain-language experience; the batch node is the "advanced"
entry. Revisit when nested collections are supported generally.

### 14.2 Configurable answer key vs. static typed output
Mock 03's "Answer key" would make the output path dynamic (`answers.<key>.choice`), defeating
static output schemas unless a resolver is added. Decision: single-question nodes use a fixed
internal question id and hoist the answer to top-level fields (`$json.choice`,
`$json.confidence`, …). Typed, drag-and-droppable, no resolver.

### 14.3 One import endpoint for install and update
A separate `update` route would duplicate validation and race handling. Decision: `POST
/node-packs` upserts by `key` under a lock with explicit result codes (8.3).

### 14.4 Pack-level credential binding
Rejected (11.4 delta): it would need a new "default credential" mechanism in the configurator
and blur the per-node dependency model the executor relies on.

### 14.5 Disable semantics

Disabled imported nodes fail closed. The Registry retains their exact definitions so the
executor can distinguish a disabled pack from an unknown node, then the dedicated pack guard
records a node error before pinned/test output and downstream execution. Ruby-plugin unavailable
nodes keep their pre-existing skip/pass-through semantics.

### 14.6 Where retired versions go

Retired definitions remain executable while the pack is installed. Removal makes them inert but
retains their immutable snapshots for audit and reinstall conflict checks. Historical references
alone do not block removal; current/active references and live executions do. A per-definition
prune action is a follow-up, not v1.

### 14.7 Template language size
Settled at five constructs (4.7). Anything a pack cannot express with them is a signal to
add a Ruby node, not to grow the language.

---

## 15. Test plan

### 15.1 RSpec (backend owner)

Manifest/validator (`spec/lib/discourse_workflows/node_packs/manifest_spec.rb`):
- T-R01 accepts the Jev example (`docs/examples/node-packs/jev.json`) with zero errors and normalizes key order.
- T-R02 rejects: unknown top-level key; identifier colliding with `action:http_request` (`identifier_reserved`); non-HTTPS destination; URL outside destinations; forbidden header; expression default; nested collection; `credential` type not allowed; `$param` referencing unknown property; `$rows` on a non-collection; template depth 9; invalid output schema; icon/colour outside allowlists; control characters in label; 21 nodes; node version `"1.0.0"` (`version_format`).
- T-R03 canonical hash ignores cosmetic keys and changes when `request.body` changes.

Template renderer (`…/template_renderer_spec.rb`):
- T-R04 `$param`, `omit_if_blank`, `$rows` object/array, `$row`, `$omit_if_empty`, `$response` missing path → `null`, duplicate row key → error, `ui.format: json` parse and error.

Services (`spec/services/discourse_workflows/node_pack/*_spec.rb`, matchers per service docs):
- T-R05 `Preview`: no DB writes, no HTTP (WebMock `a_request` never), change classification for new/unchanged/changed/conflict/dropped.
- T-R06 `Install`: install creates pack + 4 definitions; re-install identical → `unchanged`, no new rows; same version different hash → `revision_conflict`; lower version → `downgrade_not_allowed`; higher version with changed node without bump → `definition_conflict`; with bump → old definition retired, new inserted, dropped node retired, re-added identical node un-retired; missing approval → `destinations_not_approved`; non-admin → policy failure; staff action logged; runtime version bumped.
- T-R07 `Update`: enable/disable/palette flags; version bumped.
- T-R08 `Remove`: blocked by draft reference, by published reference, by `waiting` execution on an old version; not blocked by a historical-only version or by `success`/`error` executions; marks definitions inert and retains them; credentials and executions untouched.

Registry/serializer (`spec/lib/discourse_workflows/registry_node_packs_spec.rb`):
- T-R09 `find_node_type("action:jev.choice", version: "1.0")` returns a class; a disabled pack remains exactly resolvable but reports unavailable; retired versions remain resolvable; removed → nil after invalidation; Ruby node still wins for its own identifier; `NodeType.registered_nodes` excludes synthesized classes; `waiting_identifiers` unaffected.
- T-R10 `NodeTypeSerializer` emits `ui.label`, `ui.pack`, `palette_group.label`, credential slot `label`, `output_contracts` from schema; `NodeType::List` includes pack nodes.

Execution (`spec/lib/discourse_workflows/node_packs/declarative_node_spec.rb`, `spec/support/node_execution_helpers.rb`, WebMock):
- T-R11 choice node: per-item request body matches expected JSON (criteria map built from rows, blank description omitted), bearer header from credential, output hoisted and `pairedItem` set; two input items → two requests.
- T-R12 missing credential → node error; wrong credential type → `InvalidAccess` path from context.
- T-R13 429 then 200 → one retry; 3xx → error not followed; 500 → error with truncated body; response over `max_response_kb` → error; final URL outside approved origins (stubbed redirect-like env) → `destination_not_approved`.
- T-R14 noul node with both criteria blank → `criteria` key absent; batch node with invalid JSON criteria → `invalid_json_parameter`.
- T-R15 executor integration (`WorkflowGraphBuilder`): disabled pack → error step before pinned/test output and downstream execution; removed pack → fail-closed error; publish with a pinned retired version still executes that version.

Requests (`spec/requests/discourse_workflows/node_packs_controller_spec.rb`):
- T-R16 every endpoint: admin 2xx shapes per 9.1; moderator/user 403/404; error `type`s and statuses for 409/422; export has no credential fields and correct headers.

Graph validation: T-R17 saving a workflow with `typeVersion` of a retired definition succeeds; with a removed identifier fails `unsupported_node_version`.

### 15.2 QUnit (frontend owner) — `test/javascripts/…`

- T-F01 `node-types.js`: label/description/subtitle/palette group literal fallbacks and i18n precedence for Ruby nodes.
- T-F02 `property-engine.js`: `schema.label`/`description`/`placeholder` fallbacks; option `label`.
- T-F03 rendering: `<Field>` with literal description `<img src=x onerror=alert(1)>` renders escaped text; palette entry label likewise.
- T-F04 `node-panel.gjs` (rendering, fixture node types): pack group appears after built-ins with badge and subtitle; hidden/unavailable nodes excluded; search matches subtitle and pack name.
- T-F05 import modal (pretender): invalid manifest shows path/message list; preview renders nodes and change badges; install disabled until all destinations checked; 409 `definition_conflict` message; success calls `workflowsNodeTypes.clear()`.
- T-F06 manager/detail (pretender): list columns, disable/enable/palette toggles, remove 409 shows `InUseDialog` with workflow links and execution count.
- T-F07 configurator with a fixture pack node type: credential slot label literal, properties in order, `Documentation` link, output schema fields listed.

### 15.3 System specs (integration owner) — `spec/system/node_packs_spec.rb`

- T-S01 admin imports `jev.json` via paste → preview → approve → detail page shows 4 nodes, then verifies the list route.
- T-S02 a workflow loads all four example nodes from the real registry and edits Choice/Score/Noul/Batch with the generic controls, including fixed collections, leading-`=` state expression, and JSON criteria.
- T-S03 lifecycle coverage verifies disable fail-closed availability, re-enable, a behavior-preserving pack revision update, removal blocked by a current workflow, inert retained definitions after unblocked removal, and identical-definition reinstall/un-retire.

No system test calls the external example provider. HTTP execution behavior uses WebMock only in
focused backend specs; no live credential is required or used.

Screenshots for review (`.skills/discourse-screenshots`): node packs list (empty + populated),
import review step, detail page, palette pack group, choice configurator with output schema,
remove-blocked dialog — light/dark, Foundation/Horizon.

---

## 16. Work split and file ownership

Three implementers work from this document only. Names below are the only files each may
create/modify; anything else goes through the integration owner.

### 16.1 Backend owner (`chatgpt:gpt-5.6-sol-medium`)

Create:
- `db/migrate/<generated>_create_workflow_node_packs.rb`
- `app/models/discourse_workflows/node_pack.rb`, `node_pack_definition.rb`
- `lib/discourse_workflows/node_packs/limits.rb` (constants, allowlists), `manifest.rb` (parse/normalize/validate, error codes 9.2), `canonical_json.rb`, `template_renderer.rb`, `declarative_node.rb`, `class_factory.rb`, `runtime.rb` (version stamp + class cache), `usage_query.rb` (8.4 SQL)
- `app/services/discourse_workflows/node_pack/{list,show,preview,install,update,remove}.rb`
- `app/serializers/discourse_workflows/node_pack_serializer.rb`, `node_pack_detail_serializer.rb`
- `app/controllers/discourse_workflows/node_packs_controller.rb`
- `docs/examples/node-packs/jev.json`
- specs T-R01…T-R17

Modify (minimal, additive): `config/routes.rb`, `config/locales/server.en.yml`,
`lib/discourse_workflows/registry.rb` (7.2), `node_type_serializer.rb` (10.1),
`property_schema_validator.rb` (10.2), `executor/http_client.rb` (7.4),
`ai/tools/workflow_node_catalog.rb` (12), `plugin.rb` (icons in `ICONS` allowlist via
`register_svg_icon`).

### 16.2 Frontend owner (`chatgpt:gpt-5.6-sol-medium`)

Create:
- `admin/assets/javascripts/admin/components/workflows/node-pack/{manager,detail,import-modal,node-list,used-by-list}.gjs`
- `admin/assets/javascripts/discourse/routes/admin-plugins/show/discourse-workflows-node-packs.js`, `…-node-packs/{index,show}.js`
- `admin/assets/javascripts/discourse/templates/admin-plugins/show/discourse-workflows-node-packs.gjs`, `…-node-packs/{index,show}.gjs`
- `assets/stylesheets/common/node-packs/node-packs.scss` (BEM `.workflows-node-packs…`)
- `test/javascripts/…` T-F01…T-F07 with fixture node types under `test/javascripts/fixtures/node-pack-node-types.js` matching 10.1 exactly

Modify: `discourse-workflows-route-map.js`, `initializers/admin-plugin-configuration-nav.js`,
`lib/workflows/node-types.js`, `lib/workflows/property-engine.js`,
`configurators/field.gjs` (literal description escaped path),
`canvas/node-panel.gjs` (11.6), `node/configurator.gjs` (11.7 header/badge/docs link,
credential slot literal), `config/locales/client.en.yml` (11.8),
`assets/stylesheets/common/index.scss` (import).

The frontend owner develops against a pretender/fixture implementation of section 9/10
until the backend lands; the fixture is the shared contract.

### 16.3 Integration owner (after both land)

- Wire real endpoints, run T-S01…T-S04, `bin/lint --fix` on all changed files, `bin/rake annotate:clean` / structure dump for the plugin.
- Verify seams listed in section 3 once more against the merged code (especially 7.1 registration exclusion and 10.3 escaping).
- Capture screenshots (15.3) for the group review (gemini, grok, opus, muse).
- Owns any file touched by both (none by design) and conflict resolution.

---

## 17. Follow-ups (not v1)

- Per-definition prune ("delete retired versions with no references").
- Nested collections + per-row templates for structured batch editing (14.1).
- Pack-level default credential and "Add to workflow" from the detail page.
- Additional request content types (`form_urlencoded`, `raw`) and `GET` query-param templates.
- Pack signing / trusted sources and a remote catalog.
- Read-only "Used by" on the Credentials page for pack nodes (already generic through `WorkflowDependency(credential_id)`).
