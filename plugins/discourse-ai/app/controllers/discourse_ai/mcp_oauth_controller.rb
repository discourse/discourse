# frozen_string_literal: true

module DiscourseAi
  class McpOauthController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr, only: :client_metadata
    skip_before_action :preload_json, only: :client_metadata
    skip_before_action :redirect_to_login_if_required, only: :client_metadata

    def client_metadata
      render json: {
               client_name: "Discourse AI MCP Client",
               redirect_uris: [
                 "#{Discourse.base_url}/admin/plugins/discourse-ai/ai-mcp-servers/oauth/callback",
               ],
               grant_types: %w[authorization_code refresh_token],
               response_types: ["code"],
               application_type: "web",
               token_endpoint_auth_method: "none",
             }
    end
  end
end
