# frozen_string_literal: true

class AiMcpServerSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :description,
             :url,
             :auth_type,
             :ai_secret_id,
             :auth_header,
             :auth_scheme,
             :oauth_client_registration,
             :oauth_client_id,
             :oauth_client_secret_ai_secret_id,
             :oauth_scopes,
             :oauth_authorization_params,
             :oauth_token_params,
             :oauth_require_refresh_token,
             :oauth_granted_scopes,
             :oauth_token_type,
             :oauth_access_token_expires_at,
             :oauth_authorization_endpoint,
             :oauth_token_endpoint,
             :oauth_revocation_endpoint,
             :oauth_issuer,
             :oauth_resource_metadata_url,
             :oauth_status,
             :oauth_last_error,
             :oauth_last_authorized_at,
             :oauth_last_refreshed_at,
             :oauth_client_metadata_url,
             :enabled,
             :timeout_seconds,
             :last_health_status,
             :last_health_error,
             :last_checked_at,
             :last_tools_synced_at,
             :protocol_version,
             :server_capabilities,
             :tool_count,
             :token_count,
             :tool_names,
             :tools

  root "ai_mcp_server"

  def tool_count
    object.tool_count
  end

  def tool_names
    object.tools_for_serialization.map { |tool| tool[:name] }
  end

  def tools
    object.tools_for_serialization
  end

  def token_count
    object.token_count
  end

  def oauth_client_metadata_url
    object.oauth_client_metadata_url
  end
end
