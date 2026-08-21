# frozen_string_literal: true

class Admin::McpAuthorizationsController < Admin::AdminController
  def index
    authorizations =
      McpOauthAuthorization
        .includes(:user, :client, :profile, :scope_records, :access_tokens)
        .order(updated_at: :desc)
        .limit(200)
    render json: { authorizations: authorizations.map { |authorization| serialize(authorization) } }
  end

  def destroy
    authorization = McpOauthAuthorization.find(params[:id])
    authorization.revoke!(by_user: current_user, reason: "admin_revoked")
    StaffActionLogger.new(current_user).log_custom(
      "mcp_authorization_revoked",
      authorization_id: authorization.id,
      subject_user_id: authorization.user_id,
      client_id: authorization.mcp_oauth_client_id,
    )
    head :no_content
  end

  private

  def serialize(authorization)
    active_tokens =
      authorization.access_tokens.select do |token|
        token.revoked_at.nil? && token.expires_at.future?
      end
    {
      id: authorization.id,
      username: authorization.user.username,
      client_name: authorization.client.name,
      client_id: authorization.client.client_id,
      resource: authorization.resource,
      status: authorization.status,
      scopes: authorization.scopes,
      consented_at: authorization.consented_at,
      revoked_at: authorization.revoked_at,
      last_used_at: authorization.access_tokens.filter_map(&:last_used_at).max,
      token_count: active_tokens.length,
    }
  end
end
