# OAuth2 client credentials

Workflows provides generic OAuth2 client-credentials authentication for HTTP request nodes. Credentials contain a token URL, client ID, client secret, API origin, optional revocation URL, optional space-separated scope, and client authentication method. Select either request-body authentication or HTTP Basic authentication according to the provider's documentation.

The API origin is an HTTPS origin such as `https://api.example.com`. Requests using this credential must match its hostname and port. Token requests and API requests use the SSRF-protected HTTP transport and do not follow redirects with credentials.

The revocation URL is an optional RFC 7009 endpoint. When it is set, disconnecting a credential, changing its app details, or deleting it posts the cached token there; a failed revocation fails the operation rather than reporting a successful disconnection. Administrators only need a credential type of their own when a provider needs behavior no configuration field can express.

Save a credential and use **Test connection** to verify the token exchange. Workflows can also acquire a token on its first execution without a prior connection test. Secrets and tokens are encrypted at rest and excluded from serialized credentials and request logs.

## Token lifecycle

Tokens are cached per credential with a distributed lock around token acquisition and credential changes. When `expires_in` is supplied, Workflows renews the token before expiry. Without an expiry, it uses the token until an API response rejects it. Every renewal uses client credentials, not a refresh token.

Generic authentication does not replay a request after a 401 response: a provider may have performed a write before returning an error. A 401 invalidates the cached connection for the next execution. Provider integrations can recognize a documented response that guarantees the request was rejected before execution; Workflows then permits one token renewal and one replay.

Changing app details or deleting credentials clears their cached connection. Without a revocation URL, clearing a token does not revoke it remotely; disable the app or rotate credentials at the provider when remote access must be removed. Deleting a credential never disables the app itself.

## Register a provider from another plugin

A credential type supplies `identifier`, `display_name`, `property_schema`, and `oauth_provider`. The schema must include fixed `client_id` and `client_secret` fields, with the secret using the password control. Optional `setup_key` and `ui_metadata` methods provide translated setup text and field labels in the shared credential form.

Register the credential type in the contributing plugin's `after_initialize` callback:

```ruby
if defined?(DiscourseWorkflows)
  register_discourse_workflows_credential_type "ExampleApi::WorkflowCredential"
end
```

Registration uses the owning plugin's enabled setting and stores class names for reload safety. The HTTP request node automatically includes registered OAuth2 credential types in its authentication options and credential slots. No controller, model, serializer, or HTTP-client patches are needed.

Use an optional autoload directory for classes that inherit from Workflows, and add that directory only when Workflows is installed. Keep the contributing plugin's unrelated features usable without Workflows.

A provider inherits from `DiscourseWorkflows::Oauth2Provider`. Prefer the class-level declarations, which describe a provider rather than reimplementing the flow:

| Declaration | Responsibility |
| --- | --- |
| `api_origin_token_field` | Token response field holding the API origin, for providers that return a per-tenant host. Setting it removes `api_origin` from the credential's configuration and confines requests to the returned origin. |

The remaining method hooks cover behavior configuration cannot express:

| Hook | Responsibility |
| --- | --- |
| `validate_configuration(credential)` | Call `super` and add provider-specific configuration errors. |
| `token_url` / `revoke_url` | Override to derive an endpoint instead of reading it from credential data. |
| `token_parameters` / `token_headers` | Customize token exchange parameters or client authentication. |
| `validate_tokens!(tokens)` | Call `super` and validate additional response fields. |
| `identity(tokens)` | Optionally return extra connection fields describing the authenticated identity. |
| `connection_details(connection)` | Return safe, translated `{ label:, value: }` entries for administrators. Never return secrets. |
| `expired_session?(response)` | Explicitly opt a known rejected response into one renewal and replay. Defaults to false, and matters most for providers that omit `expires_in`. |

Protected `request` and `parse_response` helpers provide the shared transport and bounded JSON parsing. Raise `Oauth2Provider::Error` with a supported generic error code rather than exposing provider response bodies. `Oauth2Provider::Revoked` indicates rejected authorization.

`discourse-salesforce` is a worked example: one declaration, a derived `revoke_url`, and one `expired_session?` implementation.

Workflows owns encryption, caching, credential administration, request authentication, and retry limits. Providers own endpoint rules, identity lookup, connection details, and interpretation of provider-specific responses.

Disabled providers disappear from the authentication catalog and cannot execute. Their persisted credentials still serialize with password fields redacted. If a provider plugin is removed entirely, unknown credential data is omitted rather than exposed without its schema.
