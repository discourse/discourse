# Testing MCP theme tools with a coding agent

Use a development Discourse site. The MCP endpoint is `<site URL>/mcp`, and
the admin interface is `<site URL>/admin/config/mcp`.

## Connect an agent

In the MCP admin interface, enable the server and the three capabilities:
`discourse_get_theme`, `discourse_create_theme`, and `discourse_update_theme`.
Grant the admins group `mcp:themes:read` and `mcp:themes:write`.

Configure the coding agent's HTTP MCP client with the endpoint above. Use OAuth
with PKCE (S256), signing in as the local administrator and consenting to
`mcp:profile:read mcp:themes:read mcp:themes:write`.

For clients requiring pre-registration, register the client ID and exact callback
URI in Admin → MCP → Clients. OAuth metadata is available at
`/.well-known/oauth-authorization-server` and
`/.well-known/oauth-protected-resource/mcp`.

The read and write permissions are independent. All three tools also enforce
administrator access. A site-setting permission does not grant theme access.

## Agent testing prompt

> Test the MCP theme tools on this development site. Read Foundation (ID -1)
> and Horizon (ID -2). Create a disposable theme named "MCP agent test" with a
> common/header field containing `<div>MCP test</div>`. Read it back, update the
> header, then clear it with an empty value and verify it disappears. Create a
> disposable component. Attach it to Foundation with `child_theme_ids`, then
> move it to Horizon with `parent_theme_ids`. These arrays replace existing
> relationships: record the original IDs, preserve unrelated components, and
> restore all original relationships afterward. Request a rename together with
> `default: true` on the disposable component; expect a tool error and verify
> its name is unchanged. Send a field named `unknown_field` with target `common`
> and no type; expect an actionable tool error, not HTTP 500. With a separate
> read-only authorization, verify get works and create/update require
> `mcp:themes:write`. Report expected versus actual results. Delete only the
> disposable test theme and component through the admin UI afterward. Do not
> change the site's default theme.

## Automated regression checks

These use the separate test database and cover scope isolation, administrator
checks, built-in theme IDs, field errors, and rollback of failed updates.

```sh
bin/rspec spec/lib/discourse_mcp/staff_tools_spec.rb \
  spec/requests/mcp_content_access_spec.rb \
  spec/lib/discourse_mcp/access_spec.rb \
  spec/requests/mcp_oauth_metadata_controller_spec.rb
```
