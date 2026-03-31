import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

const CREATE_ATTRIBUTES = [
  "id",
  "name",
  "description",
  "url",
  "auth_type",
  "ai_secret_id",
  "auth_header",
  "auth_scheme",
  "oauth_client_registration",
  "oauth_client_id",
  "oauth_client_secret_ai_secret_id",
  "oauth_scopes",
  "oauth_authorization_params",
  "oauth_token_params",
  "oauth_require_refresh_token",
  "oauth_granted_scopes",
  "oauth_token_type",
  "oauth_access_token_expires_at",
  "oauth_authorization_endpoint",
  "oauth_token_endpoint",
  "oauth_revocation_endpoint",
  "oauth_issuer",
  "oauth_resource_metadata_url",
  "oauth_status",
  "oauth_last_error",
  "oauth_last_authorized_at",
  "oauth_last_refreshed_at",
  "oauth_client_metadata_url",
  "enabled",
  "timeout_seconds",
  "last_health_status",
  "last_health_error",
  "last_checked_at",
  "last_tools_synced_at",
  "protocol_version",
  "server_capabilities",
  "tool_count",
  "tool_names",
  "tools",
];

export default class AiMcpServer extends RestModel {
  createProperties() {
    return this.getProperties(CREATE_ATTRIBUTES);
  }

  updateProperties() {
    const attrs = this.createProperties();
    attrs.id = this.id;
    return attrs;
  }

  async testConnection(data) {
    const path = this.isNew
      ? "/admin/plugins/discourse-ai/ai-mcp-servers/test.json"
      : `/admin/plugins/discourse-ai/ai-mcp-servers/${this.id}/test.json`;

    return await ajax(path, {
      type: "POST",
      data: JSON.stringify({ ai_mcp_server: data }),
      contentType: "application/json",
    });
  }

  get oauthStartPath() {
    return `/admin/plugins/discourse-ai/ai-mcp-servers/${this.id}/oauth/start`;
  }

  async disconnectOAuth() {
    const response = await ajax(
      `/admin/plugins/discourse-ai/ai-mcp-servers/${this.id}/oauth/disconnect.json`,
      {
        type: "DELETE",
      }
    );

    this.setProperties(response.ai_mcp_server);
    return response.ai_mcp_server;
  }
}
