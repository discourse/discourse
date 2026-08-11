# frozen_string_literal: true

class McpOauthAuthorizationsController < ApplicationController
  layout "no_ember"
  requires_login
  skip_before_action :check_xhr, :preload_json
  before_action :validate_request

  def show
    raise Discourse::InvalidAccess if current_user.is_impersonating
    @client = DiscourseMcp::OAuth::ClientResolver.resolve!(params[:client_id])
    validate_redirect!(@client)
    @profile = McpServerProfile.ensure_default!
    @requested_scopes = requested_scopes
    raise Discourse::InvalidAccess if !@profile.available? || !@profile.user_allowed?(current_user)
    render :show
  end

  def create
    raise Discourse::InvalidAccess if current_user.is_impersonating
    client = DiscourseMcp::OAuth::ClientResolver.resolve!(params[:client_id])
    validate_redirect!(client)
    return redirect_with(error: "access_denied") if params[:decision] != "approve"

    profile = McpServerProfile.ensure_default!
    authorization =
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: current_user,
        client: client,
        profile: profile,
        redirect_uri: params[:redirect_uri],
        requested_scopes: requested_scopes,
      )
    code =
      McpOauthAuthorizationCode.issue!(
        authorization: authorization,
        redirect_uri: params[:redirect_uri],
        resource: params[:resource],
        code_challenge: params[:code_challenge],
      )
    redirect_with(code: code)
  end

  private

  def validate_request
    raise Discourse::InvalidParameters if params[:response_type] != "code"
    raise Discourse::InvalidParameters if params[:code_challenge_method] != "S256"
    if !params[:code_challenge].to_s.match?(/\A[A-Za-z0-9_-]{43}\z/)
      raise Discourse::InvalidParameters
    end
    raise Discourse::InvalidParameters if params[:resource] != DiscourseMcp.resource_url
    URI.parse(params.require(:client_id)) if params[:client_id].to_s.start_with?("https://")
    URI.parse(params.require(:redirect_uri))
  rescue URI::InvalidURIError
    raise Discourse::InvalidParameters
  end

  def validate_redirect!(client)
    raise Discourse::InvalidAccess if !client.redirect_uris.include?(params[:redirect_uri])
  end

  def requested_scopes
    params[:scope].to_s.split(" ").reject(&:blank?).uniq
  end

  def redirect_with(values)
    uri = URI.parse(params[:redirect_uri])
    query = Rack::Utils.parse_nested_query(uri.query)
    query.merge!(values.stringify_keys)
    query["state"] = params[:state] if params[:state].present?
    query["iss"] = DiscourseMcp.issuer
    uri.query = Rack::Utils.build_query(query)
    redirect_to uri.to_s, allow_other_host: true
  end
end
