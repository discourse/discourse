# OAuth2 client credentials

Workflows provides generic OAuth2 client-credentials authentication for HTTP request nodes through the built-in OAuth2 credential type. Credentials contain a token URL, client ID, client secret, API origin, optional revocation URL, optional space-separated scope, and client authentication method. Select either request-body authentication or HTTP Basic authentication according to the provider's documentation. Token requests and revocation requests use this authentication method.

The API origin is an HTTPS origin such as `https://api.example.com`. Requests using this credential must match its hostname and port. Token requests and API requests use the SSRF-protected HTTP transport and do not follow redirects with credentials.

The revocation URL is an optional RFC 7009 endpoint. When it is set, disconnecting a credential, changing its app details, or deleting it posts the cached token there; a failed revocation fails the operation rather than reporting a successful disconnection.

Save a credential and use **Test connection** to verify the token exchange. Workflows can also acquire a token on its first execution without a prior connection test. Secrets and tokens are encrypted at rest and excluded from serialized credentials and request logs.

## Token lifecycle

Tokens are cached per credential with a distributed lock around token acquisition and credential changes. When `expires_in` is supplied, Workflows renews the token with 10% of its lifetime remaining, capped at 60 seconds and rounded down to whole seconds. The same margin applies to an assumed token lifetime. Without either lifetime, it uses the token until an API response rejects it. Every renewal uses client credentials, not a refresh token.

Generic authentication does not replay a request after a 401 response: a provider may have performed a write before returning an error. A 401 invalidates the cached connection for the next execution.

Changing app details or deleting credentials clears their cached connection. Without a revocation URL, clearing a token does not revoke it remotely; disable the app or rotate credentials at the provider when remote access must be removed. Deleting a credential never disables the app itself.

If cached token data cannot be decrypted, workflow requests fail until an administrator uses **Test connection** or deletes the credential. These actions discard the unreadable token data without revocation because the token cannot be recovered. The old token can remain valid at the provider; revoke it there if needed. Readable tokens still require successful revocation when a revocation URL is configured.
