# frozen_string_literal: true

class Admin::McpAuthorizationsController < Admin::AdminController
  def index
    page =
      McpOauthAuthorizationsPage.new(
        limit: fetch_limit_from_params(default: 50, max: 100),
        cursor: fetch_int_from_params(:cursor, default: nil, min: 1),
        filter: params[:filter],
      ).call
    statuses = DiscourseMcp::AuthorizationStatus.for(page.records)
    render json: {
             authorizations:
               page.records.map do |authorization|
                 serialize(authorization, status: statuses.fetch(authorization.id))
               end,
             meta: {
               next_cursor: page.next_cursor,
             },
           }
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

  def serialize(authorization, status:)
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
      status: status,
      scopes: authorization.scopes,
      consented_at: authorization.consented_at,
      revoked_at: authorization.revoked_at,
      last_used_at: authorization.access_tokens.filter_map(&:last_used_at).max,
      token_count: active_tokens.length,
    }
  end
end
