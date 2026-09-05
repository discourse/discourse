# frozen_string_literal: true

class McpController < ApplicationController
  skip_before_action :check_xhr, :preload_json, :verify_authenticity_token
  before_action :ensure_mcp_enabled
  before_action :validate_origin

  def create
    if !request.media_type.to_s.casecmp?("application/json")
      return(
        render json: jsonrpc_error(nil, -32_600, "Content-Type must be application/json"),
               status: :unsupported_media_type
      )
    end
    accept = request.headers["Accept"].to_s
    if !accept.include?("application/json") || !accept.include?("text/event-stream")
      return(
        render json:
                 jsonrpc_error(
                   nil,
                   -32_600,
                   "Accept must include application/json and text/event-stream",
                 ),
               status: :not_acceptable
      )
    end

    request_context = DiscourseMcp::Authenticator.new(request).authenticate!
    enforce_rate_limits!(request_context)
    raw_payload = request.body.read(SiteSetting.mcp_max_request_bytes + 1) || ""
    if raw_payload.bytesize > SiteSetting.mcp_max_request_bytes
      return(
        render json: jsonrpc_error(nil, -32_600, "Request too large"), status: :payload_too_large
      )
    end

    payload = JSON.parse(raw_payload)
    mcp_response =
      DiscourseMcp::Server.new(request: request, request_context: request_context).call(payload)
    mcp_response.headers.each { |name, value| response.set_header(name, value) }
    return head mcp_response.http_status if mcp_response.body.nil?

    encoded_response = JSON.generate(mcp_response.body)
    if encoded_response.bytesize > SiteSetting.mcp_max_response_bytes
      return(
        render json: jsonrpc_error(payload["id"], -32_603, "Response too large"),
               status: :internal_server_error
      )
    end

    render json: encoded_response, status: mcp_response.http_status
  rescue RateLimiter::LimitExceeded => error
    record_rate_limited_audit(request_context)
    response.set_header("Retry-After", error.available_in.to_s)
    render json: jsonrpc_error(nil, -32_000, "Rate limit exceeded"), status: :too_many_requests
  rescue JSON::ParserError
    render json: jsonrpc_error(nil, -32_700, "Parse error"), status: :bad_request
  rescue DiscourseMcp::AuthenticationError => error
    response.set_header(
      "WWW-Authenticate",
      DiscourseMcp::Authenticator.challenge(
        scope: DiscourseMcp::INITIAL_SCOPE,
        error: error.oauth_error,
      ),
    )
    render json: jsonrpc_error(nil, -32_001, "Authorization required"), status: :unauthorized
  end

  def method_not_allowed
    head :method_not_allowed, allow: "POST"
  end

  private

  def enforce_rate_limits!(request_context)
    limit = SiteSetting.mcp_global_rate_limit_per_minute
    RateLimiter.new(
      request_context.user,
      "mcp-client-#{request_context.oauth_client_id}",
      limit,
      1.minute,
      apply_limit_to_staff: true,
    ).performed!
    RateLimiter.new(
      nil,
      "mcp-ip-#{request.remote_ip}",
      limit,
      1.minute,
      apply_limit_to_staff: true,
    ).performed!
  end

  def record_rate_limited_audit(request_context)
    bucket_at = Time.zone.now.beginning_of_minute
    audit_key =
      "mcp-rate-limit-audit:#{request_context&.user_id}:#{request_context&.oauth_client_id}:#{bucket_at.to_i}"
    return if !Discourse.redis.set(audit_key, "1", nx: true, ex: 2.minutes.to_i)

    McpAuditLog.create!(
      occurred_at: Time.zone.now,
      bucket_at:,
      user_id: request_context&.user_id,
      mcp_oauth_client_id: request_context&.oauth_client_id,
      outcome: "rate_limited",
      http_status: 429,
    )
  rescue StandardError => error
    Discourse.warn_exception(error, message: "MCP audit record failed")
  end

  def ensure_mcp_enabled
    raise Discourse::NotFound if !SiteSetting.mcp_server_enabled
  end

  def validate_origin
    origin = request.headers["Origin"]
    return if origin.blank?

    actual = URI.parse(origin)
    expected = URI.parse(DiscourseMcp.issuer)
    if actual.path.blank? && actual.userinfo.blank? &&
         [actual.scheme, actual.host, actual.port] ==
           [expected.scheme, expected.host, expected.port]
      return
    end

    render json: jsonrpc_error(nil, -32_001, "Invalid Origin"), status: :forbidden
  rescue URI::InvalidURIError
    render json: jsonrpc_error(nil, -32_001, "Invalid Origin"), status: :forbidden
  end

  def jsonrpc_error(id, code, message)
    { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
  end
end
