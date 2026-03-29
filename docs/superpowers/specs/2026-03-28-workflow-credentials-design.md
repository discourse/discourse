# Workflow Credentials System

Design spec for adding credential management to the discourse-workflows plugin. Credentials allow workflows to securely store and reference authentication data (starting with Basic Auth for the Webhook trigger).

## Context

n8n provides a credential system where credentials are stored encrypted in a dedicated table, typed via credential type classes with form schemas, referenced by ID on nodes, and decrypted at runtime. This design adapts that pattern to Discourse's Rails/Ember stack.

Currently the plugin has no secret storage. The `Variable` model stores plain text key-value pairs. The `AiSecret` model in discourse-ai also stores secrets as plaintext. This design introduces encrypted-at-rest storage for credentials, which is appropriate given they hold third-party passwords.

## Database Model

New table: `discourse_workflows_credentials`

| Column | Type | Constraints |
|---|---|---|
| `id` | bigint | PK, auto-increment |
| `name` | string(128) | required |
| `credential_type` | string(64) | required, indexed |
| `data` | text | encrypted JSON blob |
| `created_at` | datetime | |
| `updated_at` | datetime | |

- `name`: human-readable label, e.g. "Stripe webhook auth"
- `credential_type`: identifier matching a registered credential type, e.g. `basic_auth`
- `data`: output of `ActiveSupport::MessageEncryptor#encrypt_and_sign` — contains the JSON-serialized form values (e.g. `{"user":"admin","password":"secret123"}`)
- No sharing/scoping tables — all credentials are global and admin-only

## Encryption

A utility class `DiscourseWorkflows::CredentialEncryptor`:

- **Key derivation**: `ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key("discourse-workflows-credentials", 32)` produces a 32-byte AES key specific to this purpose
- **Encrypt**: `JSON.generate(hash)` then `encryptor.encrypt_and_sign(json_string)` — AES-256-GCM with authentication tag
- **Decrypt**: `encryptor.decrypt_and_verify(encrypted_string)` then `JSON.parse`
- **Model integration**: `Credential` model exposes `decrypted_data` / `decrypted_data=` accessors. The raw `data` column is never exposed directly outside the model.

### Frontend redaction

The serializer never sends decrypted values. Each value in the `data` hash is replaced with the sentinel `__REDACTED__`. On update, the backend detects sentinel values and preserves the original stored values for those fields, then re-encrypts the merged result. This follows n8n's `CREDENTIAL_BLANKING_VALUE` pattern.

## Credential Type System

Credential types are Ruby classes registered via `Registry`, analogous to node types. Each defines a `configuration_schema` using the same schema format as nodes.

```ruby
module DiscourseWorkflows
  module CredentialTypes
    class BasicAuth
      def self.identifier
        "basic_auth"
      end

      def self.display_name
        "Basic Auth"
      end

      def self.configuration_schema
        {
          user: {
            type: :string,
            required: true,
            ui: { expression: true },
          },
          password: {
            type: :string,
            required: true,
            ui: { expression: true, control: :password },
          },
        }
      end
    end
  end
end
```

- Registered via `Registry.register_credential_type(BasicAuth)`
- No versioning — credential schemas are simple data bags unlikely to change. If needed, a new type identifier (e.g. `basic_auth_v2`) is a sufficient escape hatch.
- The `/node-types` endpoint response is extended to include a `credential_types` key with each type's `identifier`, `display_name`, and `configuration_schema`
- The frontend property engine is reused for credential forms, but requires the following extensions:

### Property engine extensions required

1. **`password` control**: `fieldInputType()` currently returns `"number"` or `"text"`. It needs to recognize `ui.control: :password` and return `"password"` so the field renders as `<input type="password">` (masked input). This maps through the existing `input-${inputType}` path in `fieldType`.

2. **`credential` field type**: `fieldControl()` does not recognize `type: :credential`. A new `credential` case must be added that renders a credential picker component — a dropdown of matching credentials (filtered by `credential_type` from the schema) plus a "Set up credential" button. This is registered as a custom control in `BUILT_IN_FIELD_CONTROLS`.

3. **Expression mode persistence for redacted values**: `isExpression()` infers expression mode by checking if the stored value starts with `=`. When the serializer redacts an expression-backed secret (e.g. `= {{ $vars.webhook_user }}` becomes `__REDACTED__`), edit mode loses whether the original value was fixed or dynamic. To fix this, the serializer must return a parallel `data_modes` hash alongside `data`, indicating per-field whether the value is `"expression"` or `"fixed"` (e.g. `{"user": "fixed", "password": "expression"}`). The credential form uses `data_modes` to set the initial Fixed/Expression toggle state rather than inspecting the redacted value.

## Backend

### Routes

```ruby
# HTML (format: false) — serves Ember shell
get "/credentials" => "admin#index"

# JSON API (format: :json)
get "/credentials" => "credentials#index"
post "/credentials" => "credentials#create"
put "/credentials/:id" => "credentials#update"
delete "/credentials/:id" => "credentials#destroy"
```

### Controller

`CredentialsController` follows the same pattern as `VariablesController`:
- All actions delegate to `Service::Base` classes
- All require `can_manage_workflows` policy
- Staff action logging for audit trail (`discourse_workflows_credential_created`, `_updated`, `_destroyed`)

### Services

- **`Credential::List`**: Cursor-based pagination (25 default, 100 max), ordered by `id DESC`. Returns `load_more_url` and `total_rows_credentials`.
- **`Credential::Create`**: Validates name and credential_type (must match a registered type), validates data against the type's schema, encrypts data, creates record.
- **`Credential::Update`**: Handles sentinel detection — for each field still set to `__REDACTED__`, preserves the original decrypted value. Merges, re-encrypts, saves.
- **`Credential::Destroy`**: Before deleting, scans all `DiscourseWorkflows::Node` records for any whose `configuration` JSONB contains a matching `credential_id`. If references exist, the deletion is blocked and the service returns an error listing the workflow names that use the credential. The frontend shows this error to the admin so they can remove references first.

### Serializer

`CredentialSerializer` exposes: `id`, `name`, `credential_type`, `data`, `data_modes`, `created_at`, `updated_at`.

- `data`: redacted hash — every value replaced with `__REDACTED__`. Secrets never leave the server.
- `data_modes`: hash indicating per-field whether the original value is `"expression"` or `"fixed"` (e.g. `{"user": "fixed", "password": "expression"}`). Derived by checking if each decrypted value starts with `=`. This lets the frontend restore the correct Fixed/Expression toggle state on edit without seeing the actual secret.

## Frontend

### Admin credentials page

Route: `/admin/plugins/discourse-workflows/credentials`

Navigation: "Credentials" tab added to the admin plugin nav alongside Variables.

**`CredentialsManager` component** — mirrors `VariablesManager`:
- Loads credentials list via `GET /credentials.json`
- Infinite scroll with `LoadMore` (cursor pagination)
- Table columns: Name, Type (display name), Created date, Actions (edit/delete)
- "New credential" button opens the modal
- Delete with confirmation dialog

**`CredentialModal` component** — create/edit modal:
- Top section: `name` text input + `credential_type` dropdown (lists registered types from `/node-types` response)
- When type is selected, renders the matching `configuration_schema` via `PropertyEngineField` components
- On create: type dropdown is editable
- On edit: type is read-only, name is editable, schema fields show `__REDACTED__` placeholders
- Expression toggle (Fixed/Expression) available on fields with `ui: { expression: true }`
- Save sends form data to API; backend handles encryption and sentinel merging

### Credential picker on nodes

New field type `:credential` for `configuration_schema`:

```ruby
authentication: {
  type: :options,
  options: %w[none basic_auth],
  default: "none",
  ui: { expression: true },
},
credential_id: {
  type: :credential,
  credential_type: :basic_auth,
  visible_if: { authentication: %w[basic_auth] },
},
```

The property engine recognizes `type: :credential` and renders:
- A dropdown populated with all credentials matching the `credential_type` filter (the existing `GET /credentials.json` endpoint accepts an optional `type` query param to filter by `credential_type` — response already omits secrets via redaction)
- A "Set up credential" button that opens `CredentialModal` inline for creation without leaving the editor
- After inline creation, the new credential is auto-selected

## Runtime: Webhook Basic Auth Validation

### Multiple matching webhooks

Today `Webhook::Receive` fans out to every enabled webhook node matching the same path + HTTP method. There is no uniqueness constraint on path/method across workflows. Authentication is enforced **per-node, not per-request** — each matching webhook node independently decides whether the request passes its auth requirements.

### Validation flow

After `find_webhook_nodes` returns all matching nodes, each node is checked individually before execution:

1. Read `authentication` from the node's configuration
2. If `"none"` — node proceeds as today
3. If `"basic_auth"`:
   a. Load the `Credential` record by `credential_id`
   b. Decrypt the data
   c. Resolve any expressions in credential values (user/password may contain `= {{ $vars.webhook_user }}`). The expression resolver requires the `= {{ ... }}` syntax for whole expressions or `= text {{ ... }}` for templates — bare `= $vars.x` without braces is not evaluated. Available expression context at this point: `$vars` and `$site_settings` only — trigger data doesn't exist yet (pre-execution gate)
   d. Parse the incoming `Authorization` header via `ActionController::HttpAuthentication::Basic.decode_credentials(request)`
   e. Compare user and password using `ActiveSupport::SecurityUtils.secure_compare` (timing-safe)
   f. No match or no header: **skip this node** (do not execute its workflow). Log the auth failure.
   g. Match: proceed to execute this node's workflow

This means if two webhook nodes share the same path — one with basic auth required and one with `authentication: "none"` — an unauthenticated request will only trigger the unprotected workflow. The protected workflow is silently skipped. Each admin independently controls their workflow's auth policy.

If **all** matching nodes require auth and the request fails all of them, return `401 Unauthorized` with `WWW-Authenticate: Basic realm="Webhook"`. If at least one node accepted the request (either `"none"` or auth passed), the request succeeds.

### Error cases

- Credential record not found (should not happen — deletion is blocked while referenced, but as a safety net): skip the node, log the error
- Decryption failure: skip the node, log the error
- These are per-node errors — they do not prevent other matching nodes from executing

## Test Matrix

### Duplicate webhook routes

| Scenario | Expected |
|---|---|
| Two nodes on same path/method, both `authentication: "none"` | Both workflows execute |
| Two nodes on same path/method, one requires basic auth, one `"none"` — request has no auth header | Only the unprotected workflow executes |
| Two nodes on same path/method, one requires basic auth, one `"none"` — request has valid auth | Both workflows execute |
| Two nodes on same path/method, both require basic auth with different credentials — request matches one | Only the matched workflow executes |
| Two nodes on same path/method, both require basic auth — request matches neither | 401 returned, no workflow executes |

### Credential deletion safeguard

| Scenario | Expected |
|---|---|
| Delete credential not referenced by any node | Deletion succeeds |
| Delete credential referenced by one workflow node | Deletion blocked, error lists the workflow name |
| Delete credential referenced by nodes in multiple workflows | Deletion blocked, error lists all workflow names |
| Delete credential, then remove node reference, then delete again | Deletion succeeds on second attempt |

### Expression-backed credentials in edit mode

| Scenario | Expected |
|---|---|
| Create credential with fixed user + fixed password | Edit form shows both fields in Fixed mode with `__REDACTED__` values |
| Create credential with expression password (`= {{ $vars.secret }}`) | Edit form shows password in Expression mode (via `data_modes`), value is `__REDACTED__` |
| Edit credential, leave redacted expression field unchanged | Save preserves original expression, does not store `__REDACTED__` |
| Edit credential, overwrite redacted field with new fixed value | Save stores the new value, `data_modes` updates to `"fixed"` |
| Edit credential, switch fixed field to expression mode | Save stores the expression string |

### 401 challenge responses

| Scenario | Expected |
|---|---|
| Webhook requires basic auth, request has no `Authorization` header | 401 with `WWW-Authenticate: Basic realm="Webhook"` |
| Webhook requires basic auth, request has wrong credentials | Node skipped (no execution) |
| Webhook requires basic auth, request has correct credentials | Workflow executes |
| Webhook `authentication: "none"`, request has no auth header | Workflow executes normally |
| Webhook requires basic auth, credential record missing (safety net) | Node skipped, error logged |
