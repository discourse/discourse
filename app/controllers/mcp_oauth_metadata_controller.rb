# frozen_string_literal: true

class McpOauthMetadataController < ApplicationController
  skip_before_action :check_xhr, :preload_json
  before_action :ensure_mcp_enabled

  def protected_resource
    render json: {
             resource: DiscourseMcp.resource_url,
             authorization_servers: [DiscourseMcp.issuer],
             scopes_supported: [DiscourseMcp::INITIAL_SCOPE],
             bearer_methods_supported: ["header"],
           }
  end

  def authorization_server
    render json: {
             issuer: DiscourseMcp.issuer,
             authorization_endpoint: "#{Discourse.base_url}/oauth2/mcp/authorize",
             token_endpoint: "#{Discourse.base_url}/oauth2/mcp/token",
             revocation_endpoint: "#{Discourse.base_url}/oauth2/mcp/revoke",
             response_types_supported: ["code"],
             grant_types_supported: %w[authorization_code refresh_token],
             code_challenge_methods_supported: ["S256"],
             authorization_response_iss_parameter_supported: true,
             client_id_metadata_document_supported:
               SiteSetting.mcp_oauth_client_trust_policy != "pre_registered",
             token_endpoint_auth_methods_supported: ["none"],
             scopes_supported: DiscourseMcp.registry.scopes,
           }
  end

  private

  def ensure_mcp_enabled
    raise Discourse::NotFound if !SiteSetting.mcp_server_enabled
  end
end
