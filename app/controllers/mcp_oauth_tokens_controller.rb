# frozen_string_literal: true

class McpOauthTokensController < ApplicationController
  OAUTH_PARAMETERS = %w[code refresh_token token code_verifier].freeze

  skip_before_action :check_xhr, :preload_json, :verify_authenticity_token
  before_action :validate_request_format

  def create
    token_response =
      case params[:grant_type]
      when "authorization_code"
        DiscourseMcp::OAuth::TokenIssuer.exchange_code!(
          code: params.require(:code),
          client_id: params.require(:client_id),
          redirect_uri: params.require(:redirect_uri),
          code_verifier: params.require(:code_verifier),
          resource: params.require(:resource),
        )
      when "refresh_token"
        DiscourseMcp::OAuth::TokenIssuer.refresh!(
          refresh_token: params.require(:refresh_token),
          client_id: params.require(:client_id),
          resource: params.require(:resource),
          requested_scopes: params[:scope].presence&.split(" "),
        )
      else
        return oauth_error("unsupported_grant_type")
      end
    no_store!
    render json: token_response
  rescue Discourse::InvalidAccess
    oauth_error("invalid_grant", status: :bad_request)
  rescue ActionController::ParameterMissing
    oauth_error("invalid_request", status: :bad_request)
  end

  def revoke
    DiscourseMcp::OAuth::TokenIssuer.revoke!(params.require(:token))
    no_store!
    head :ok
  rescue ActionController::ParameterMissing
    oauth_error("invalid_request", status: :bad_request)
  end

  private

  def validate_request_format
    if !request.media_type.to_s.casecmp?("application/x-www-form-urlencoded") ||
         (request.query_parameters.keys & OAUTH_PARAMETERS).present?
      oauth_error("invalid_request", status: :bad_request)
    end
  end

  def no_store!
    response.set_header("Cache-Control", "no-store")
    response.set_header("Pragma", "no-cache")
  end

  def oauth_error(error, status: :bad_request)
    no_store!
    render json: { error: error }, status: status
  end
end
