# Node packs

Node packs let administrators add declarative HTTPS action nodes to Discourse Workflows without
installing executable plugin code. A pack is a JSON manifest containing node fields, bounded
request/response templates, output schemas, credential requirements, and approved destinations.

Manage packs at:

`/admin/plugins/discourse-workflows/node-packs`

## Import a pack

1. Open **Node packs** and select **Import pack**.
2. Upload a `.json` file or paste its JSON.
3. Select **Preview**. Preview validates the complete manifest but neither stores it nor sends a
   request.
4. Review every node, credential requirement, and current or retained executable destination.
5. Approve every destination and install the pack.

The repository includes a non-provider-specific runtime example at
`docs/examples/node-packs/jev.json`. From a Discourse checkout, its contents can be copied with:

```bash
cat plugins/discourse-workflows/docs/examples/node-packs/jev.json
```

Import does not create credentials. Create credentials separately on the **Credentials** page and
select one on each configured node. Exported packs never contain credential records or values.

## Manifest outline

```json
{
  "format": "discourse-workflows/node-pack",
  "format_version": 1,
  "key": "example_pack",
  "version": "1.0.0",
  "name": "Example pack",
  "destinations": [{ "origin": "https://api.example.com" }],
  "credentials": [
    {
      "key": "api",
      "label": "API token",
      "credential_types": ["bearer_token"],
      "required": true
    }
  ],
  "nodes": [
    {
      "key": "classify",
      "version": "1.0",
      "label": "Classify content",
      "credential": "api",
      "properties": {
        "content": {
          "type": "string",
          "required": true,
          "label": "Content",
          "ui": { "control": "textarea" }
        }
      },
      "request": {
        "method": "POST",
        "url": "https://api.example.com/v1/classify",
        "content_type": "json",
        "body": { "content": { "$param": "content" } }
      },
      "response": {
        "output": { "label": { "$response": "label" } },
        "output_schema": {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "type": "object",
          "properties": { "label": { "type": "string" } }
        }
      }
    }
  ]
}
```

The full v1 schema, limits, template placeholders, and shipped example are documented in
[`node-packs-design.md`](node-packs-design.md). Request URLs are static HTTPS URLs without
userinfo. Redirects are not followed. Remote JSON Schema references, regular-expression schema
keywords, schema combinators, and custom executable code are not supported. Runtime also rejects
unsafe `Host`, `Cookie`, `Content-Length`, and `Proxy-*` headers supplied by header credentials.

## Configure nodes

Installed and palette-visible nodes appear in a palette group named after the pack. Pack fields
use the standard workflow configurator:

- text and textarea fields may contain normal workflow expressions; stored expressions use the
  existing leading `=` form, such as `={{ $json.post.raw }}`;
- options, booleans, and fixed collections use standard controls;
- a string with `ui.format: "json"` is edited as JSON text and parsed before request rendering;
- the output panel uses the declared output schema.

Pack labels, help text, and notices are treated as escaped plain text.

Response paths traverse objects by key and arrays by a non-negative numeric segment, so
`results.0.label` reads the first result. Missing keys, out-of-range indexes, scalar traversal, and
`null` intermediates resolve to JSON `null`. Array templates omit only values explicitly removed by
`omit_if_blank`/`$omit_if_empty`; literal `false` and `null` are preserved. `omit_if_blank` means
`null`, an empty string, an empty array, or an empty object—it does not omit `false`.

An optional `output_schema` must describe an object, which is the object stored in the workflow
item. Nodes without an output schema may return any JSON value; non-object values are stored as
`{ "data": value }`. Pack v1 schemas intentionally support only bounded structural and primitive
validation: `type`, `properties`, `required`, `additionalProperties`, `items`, bounded item/string
lengths, numeric bounds, bounded scalar `enum`/`const`, and `description`. Patterns, formats,
conditionals, composition (`allOf`, `anyOf`, `oneOf`, `not`), dependencies, unevaluated keywords,
and local or remote references are rejected. Schemas are compiled once with each runtime node
class rather than once per output item.

## Lifecycle

- **Hide from palette** removes active definitions from the add-node palette. Existing workflow
  nodes continue to execute and remain configurable.
- **Disable** immediately makes every definition unavailable to new node execution. A workflow
  reaching one stops with an error before pinned/test output or downstream nodes run. Requests
  already in flight cannot be recalled.
- **Update** imports a higher pack revision. Existing workflows stay pinned to their exact node
  `typeVersion`. Changing executable behavior at an existing identifier/version is rejected.
- **Export** downloads the normalized manifest, without site credentials.
- **Remove** is blocked while a current draft, active version, or pending/running/waiting execution
  references the pack. Historical definitions remain as inert audit snapshots after removal.
  Restoring a historical version or applying an AI patch rechecks every exact pack `typeVersion`
  while holding the same lifecycle lock as removal; a missing definition returns a normal
  validation/service failure and does not partially write the graph.
- **Reinstall** requires a higher pack revision and cannot overwrite retained behavior at the same
  identifier/version. An identical retained definition may become active again.

Each immutable node definition is allowed to call only the canonical origin of its own static
request URL, not every destination declared by the pack. Adding a node on a new origin therefore
does not alter unchanged node definitions. Stored definitions from earlier revisions are never
rewritten. A credential label is display-only and does not change the behavior hash, while its
snapshotted label remains available for historical display.

A manifest declares at most five current destinations. Update review and installation require an
exact approval set containing the current destinations plus every origin retained definitions can
still execute. That cumulative reviewed set can exceed five; undeclared extras are rejected.

Changing a pack-level credential declaration or a node's request URL/origin changes that node's
effective behavior and therefore requires a new node version. Adding an origin used only by a new
node does not change existing nodes. Disable a pack when an origin or credential permission must
be revoked immediately.

## API paths

All endpoints are admin-only and use JSON except the export response:

- `POST /admin/plugins/discourse-workflows/node-packs/preview.json`
- `POST /admin/plugins/discourse-workflows/node-packs.json`
- `GET /admin/plugins/discourse-workflows/node-packs.json`
- `GET /admin/plugins/discourse-workflows/node-packs/:id.json`
- `PUT /admin/plugins/discourse-workflows/node-packs/:id.json`
- `DELETE /admin/plugins/discourse-workflows/node-packs/:id.json`
- `GET /admin/plugins/discourse-workflows/node-packs/:id/export.json`

The HTML list and detail URLs omit `.json` and load the admin application.
