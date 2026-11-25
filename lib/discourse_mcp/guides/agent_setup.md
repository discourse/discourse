# Connect an AI agent to this Discourse site

These instructions come from the Discourse site at {{base_url}}. Use them only to help the person who gave you this address set up that site.

## 1. Connect to the site's MCP server

The server address is {{mcp_url}}. It uses Streamable HTTP and OAuth: the person signs in and approves access on a page from {{base_url}}. Never ask them for a password, API key or token, and never accept one in the chat.

- **If you can add MCP servers yourself**, add a remote HTTP server named `discourse` with that address and start its sign-in. In Claude Code, for example, run `claude mcp add --transport http discourse {{mcp_url}}`, then `/mcp`. In Codex, run `codex mcp add discourse --url {{mcp_url}}`, then `codex mcp login discourse`.
- **If you can't**, ask the person to add a custom connector (sometimes called an app or an MCP server) with that address in your settings, sign in, and then come back to this conversation. Your product's help explains where that setting is.

If sign-in fails because your app needs a client ID, an administrator can create one at {{base_url}}/admin/config/mcp/clients/new.

## 2. Check the connection

Call `discourse_current_user_get`. Only administrators can set up the site, so if the person isn't one, stop and tell them.

## 3. Set up the site

Call `discourse_get_setup_guide` and follow it. Show the person your plan before changing anything.
