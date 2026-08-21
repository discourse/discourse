# frozen_string_literal: true

class McpUserAuthorizationsController < ApplicationController
  requires_login

  def index
    ensure_self!
    authorizations =
      current_user
        .mcp_oauth_authorizations
        .includes(:client, :scope_records, :access_tokens)
        .order(updated_at: :desc)
    render json: { authorizations: authorizations.map { |authorization| serialize(authorization) } }
  end

  def destroy
    ensure_self!
    authorization = current_user.mcp_oauth_authorizations.find(params[:id])
    authorization.revoke!(by_user: current_user, reason: "user_revoked")
    head :no_content
  end

  private

  def ensure_self!
    raise Discourse::InvalidAccess if current_user.username_lower != params[:username].to_s.downcase
  end

  def serialize(authorization)
    active_tokens =
      authorization.access_tokens.select do |token|
        token.revoked_at.nil? && token.expires_at.future?
      end
    {
      id: authorization.id,
      client_name: authorization.client.name,
      client_id: authorization.client.client_id,
      resource: authorization.resource,
      status: authorization.status,
      scopes: authorization.scopes,
      authorized_at: authorization.consented_at,
      consented_at: authorization.consented_at,
      last_used_at: authorization.access_tokens.filter_map(&:last_used_at).max,
      token_count: active_tokens.length,
    }
  end
end
