# frozen_string_literal: true

# OAuth dynamic client registration (RFC 7591) for MCP clients. Apps call it
# before anyone has signed in, so it is rate limited by address and per site.
class McpOauthRegistrationsController < ApplicationController
  MAX_REQUEST_BYTES = 16.kilobytes
  REGISTRATIONS_PER_IP_PER_HOUR = 20
  REGISTRATIONS_PER_HOUR = 100

  skip_before_action :check_xhr,
                     :preload_json,
                     :verify_authenticity_token,
                     :redirect_to_login_if_required
  before_action :ensure_registration_allowed

  def create
    no_store!
    if !request.media_type.to_s.casecmp?("application/json")
      return registration_error("invalid_client_metadata", "Send the metadata as JSON.")
    end

    enforce_rate_limits!
    body = request.body.read(MAX_REQUEST_BYTES + 1).to_s
    if body.bytesize > MAX_REQUEST_BYTES
      return registration_error("invalid_client_metadata", "The metadata is too large.")
    end

    render json: DiscourseMcp::OAuth::ClientRegistration.register!(JSON.parse(body)),
           status: :created
  rescue JSON::ParserError
    registration_error("invalid_client_metadata", "The metadata must be valid JSON.")
  rescue DiscourseMcp::OAuth::ClientRegistration::Error => error
    registration_error(error.code, error.message)
  end

  private

  def ensure_registration_allowed
    if !SiteSetting.mcp_server_enabled || !DiscourseMcp::OAuth::ClientRegistration.allowed?
      raise Discourse::NotFound
    end
  end

  def enforce_rate_limits!
    RateLimiter.new(
      nil,
      "mcp-registration-ip-#{request.remote_ip}",
      REGISTRATIONS_PER_IP_PER_HOUR,
      1.hour,
      apply_limit_to_staff: true,
    ).performed!
    RateLimiter.new(
      nil,
      "mcp-registration",
      REGISTRATIONS_PER_HOUR,
      1.hour,
      apply_limit_to_staff: true,
    ).performed!
  end

  def no_store!
    response.set_header("Cache-Control", "no-store")
    response.set_header("Pragma", "no-cache")
  end

  def registration_error(error, description)
    render json: { error:, error_description: description }, status: :bad_request
  end
end
