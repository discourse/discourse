# frozen_string_literal: true

class McpOauthMetadataController < ApplicationController
  skip_before_action :check_xhr, :preload_json
  before_action :ensure_mcp_enabled

  def protected_resource
    profile = McpServerProfile.default
    render json: {
             resource: DiscourseMcp.resource_url,
             authorization_servers: [DiscourseMcp.issuer],
             scopes_supported: profile&.allowed_scopes || McpServerProfile::DEFAULT_SCOPES,
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
             client_id_metadata_document_supported: true,
             token_endpoint_auth_methods_supported: ["none"],
             scopes_supported:
               McpServerProfile.default&.allowed_scopes || McpServerProfile::DEFAULT_SCOPES,
           }
  end

  private

  def ensure_mcp_enabled
    raise Discourse::NotFound if !SiteSetting.mcp_server_enabled
  end
end
