# frozen_string_literal: true

class UserApiKeysController < ApplicationController
  requires_login only: %i[
                   create
                   create_otp
                   revoke
                   undo_revoke
                   authorize_device_request
                   deny_device_request
                 ]
  skip_before_action :redirect_to_login_if_required,
                     :redirect_to_profile_if_required,
                     only: %i[new otp activate create_device_request poll_device_request]
  skip_before_action :check_xhr, :preload_json
  skip_before_action :verify_authenticity_token, only: %i[create_device_request poll_device_request]
  before_action :set_device_auth_no_store,
                only: %i[
                  new
                  otp
                  create
                  create_otp
                  create_device_request
                  poll_device_request
                  activate
                  authorize_device_request
                  deny_device_request
                ]

  AUTH_API_VERSION = 4
  ALLOWED_PADDING_MODES = %w[pkcs1 oaep].freeze
  DEVICE_REQUESTS_PER_MINUTE = 20
  DEVICE_POLLS_PER_MINUTE = 60
  DEVICE_ACTIVATION_ATTEMPTS_PER_MINUTE = 10
  DEVICE_ACTIVATION_ATTEMPTS_PER_HOUR = 30
  DEVICE_REQUEST_TOKEN_LOOKUPS_PER_MINUTE = 30
  DEVICE_REQUEST_TOKEN_LOOKUPS_PER_HOUR = 120

  def new
    if request.head?
      head :ok, auth_api_version: AUTH_API_VERSION, auth_api_device_code: "true"
      return
    end

    json = user_api_key_authorization_model
    return if performed?

    render_user_api_key_authorization(json)
  rescue Discourse::InvalidAccess => exception
    trace_device_auth(
      "device_auth.authorization.rendered_generic",
      reason: exception.class.name,
      exception: exception,
      client_id: params[:client_id],
    )
    render_user_api_key_authorization(
      { state: UserApiKey::DeviceAuth::AUTHORIZATION_STATE_GENERIC_ERROR },
    )
  rescue Discourse::InvalidParameters => exception
    raise if exception.message == "padding"

    trace_device_auth(
      "device_auth.authorization.rendered_generic",
      reason: exception.class.name,
      exception: exception,
      client_id: params[:client_id],
    )
    render_user_api_key_authorization(
      { state: UserApiKey::DeviceAuth::AUTHORIZATION_STATE_GENERIC_ERROR },
    )
  end

  def create
    require_params
    find_client
    require_client_params
    validate_params
    validate_auth_redirect

    raise Discourse::InvalidAccess unless meets_tl?

    scopes = params[:scopes].split(",")
    expires_at = requested_expires_at(parse_expires_in_seconds!)

    @client = UserApiKeyClient.new(client_id: params[:client_id]) if @client.blank?
    @client.application_name = params[:application_name] if params[:application_name].present?
    @client.save! if @client.new_record? || @client.changed?

    # destroy any old keys the user had with the client
    @client.keys.where(user_id: current_user.id).destroy_all

    key =
      @client.keys.create!(
        user_id: current_user.id,
        push_url: params[:push_url],
        expires_at: expires_at,
        scopes: scopes.map { |name| UserApiKeyScope.new(name: name) },
      )

    # we keep the payload short so it encrypts easily with public key
    # it is often restricted to 128 chars
    payload = { key: key.key, nonce: params[:nonce], push: key.has_push?, api: AUTH_API_VERSION }
    payload[:expires_at] = key.expires_at.iso8601 if key.expires_at
    @payload = payload.to_json

    UserApiKey::DeviceAuth::Crypto.validate_payload_size!(
      @payload,
      parsed_public_key,
      padding: params[:padding],
    )
    @payload =
      Base64.encode64(
        UserApiKey::DeviceAuth::Crypto.encrypt!(
          parsed_public_key,
          @payload,
          padding: params[:padding],
        ),
      )

    if scopes.include?("one_time_password")
      # encrypt one_time_password separately to bypass 128 chars encryption limit
      otp_payload = one_time_password(parsed_public_key, current_user.username)
    end

    response_json =
      if params[:auth_redirect]
        uri = URI.parse(params[:auth_redirect])
        query_attributes = [uri.query, "payload=#{CGI.escape(@payload)}"]
        if scopes.include?("one_time_password")
          query_attributes << "oneTimePassword=#{CGI.escape(otp_payload)}"
        end
        uri.query = query_attributes.compact.join("&")

        { redirect_url: uri.to_s }
      else
        instructions =
          I18n.t("user_api_key.instructions", application_name: @client.application_name)
        { payload: @payload, instructions: instructions }
      end

    respond_to do |format|
      format.html do
        if response_json[:redirect_url]
          redirect_to(response_json[:redirect_url], allow_other_host: true)
        else
          store_preloaded("user_api_key_result", MultiJson.dump(response_json))
          raise ApplicationController::RenderEmpty.new
        end
      end
      format.json { render json: response_json }
    end
  end

  def create_device_request
    ensure_json_request!
    rate_limit_device_request_creation

    UserApiKey::DeviceAuth::CreateRequest.call(device_auth_service_params) do
      on_success do |device_request:|
        verification_uri = UrlHelper.absolute_without_cdn(path("/user-api-key/activate"))

        render json: {
                 device_code: device_request[:device_code],
                 user_code: device_request[:user_code],
                 verification_uri: verification_uri,
                 verification_uri_with_request:
                   "#{verification_uri}?request=#{CGI.escape(device_request[:request_token])}",
                 expires_in: UserApiKey::DeviceAuth::DEVICE_AUTH_TTL.to_i,
                 interval: UserApiKey::DeviceAuth::DEVICE_AUTH_INTERVAL,
               }
      end
      on_failed_contract do |failure|
        trace_device_auth(
          "device_auth.create.failed",
          reason: "contract_invalid",
          contract_errors: failure.errors&.attribute_names&.join(","),
        )
        raise Discourse::InvalidParameters.new(:base)
      end
      on_exceptions(Discourse::InvalidParameters, Discourse::InvalidAccess) do |exception|
        trace_device_auth(
          "device_auth.create.failed",
          reason: exception.class.name,
          exception: exception,
          client_id: params[:client_id],
        )
        raise exception
      end
    end
  end

  def activate
    unless current_user
      request_token = params[:request].to_s
      destination =
        if UserApiKey::DeviceAuth::CodeRegistry.valid_request_token?(request_token)
          "#{path("/user-api-key/activate")}?request=#{CGI.escape(request_token)}"
        else
          path("/user-api-key/activate")
        end

      redirect_anonymous_to_login(destination)
      return
    end

    if request.get?
      if params[:code].present?
        redirect_to path("/user-api-key/activate")
        return
      end

      render_device_activation(device_activation_model)
      return
    end

    rate_limit_device_activation_attempt

    result = device_user_activation.find_manual_code(params[:code])

    if result.status == :invalid_code
      render_device_activation(
        { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE, invalid_code: true },
        debug_reason: result.debug_reason,
      )
      return
    end

    if result.status == :expired_code
      render_device_activation(
        { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE, expired_code: true },
        debug_reason: result.debug_reason,
      )
      return
    end

    @device_auth = result.grant

    unless meets_tl?
      render_device_activation(
        device_authorization_model(
          state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_AUTHORIZE,
          no_trust_level: true,
        ),
        debug_reason: "insufficient_trust_level",
      )
      return
    end

    approval_token = device_user_activation.create_approval_token!(result.grant)

    if approval_token.blank?
      render_device_activation(
        { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE, expired_code: true },
        debug_reason: "approval_token_not_created",
      )
      return
    end

    render_device_activation(
      device_authorization_model(
        state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_AUTHORIZE,
        approval_token: approval_token,
      ),
    )
  end

  def authorize_device_request
    unless meets_tl?
      trace_device_auth("device_auth.authorize.failed", reason: "insufficient_trust_level")
      raise Discourse::InvalidAccess
    end

    device_code = device_code_for_authorize_request

    if device_code.blank?
      if @request_token.present? && @device_auth&.application_name.present?
        render_device_activation(
          device_authorization_model(
            state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_AUTHORIZE,
            request_token: @request_token,
            invalid_code: true,
          ),
          debug_reason: @device_auth_debug_reason || "invalid_request_token_code",
        )
      else
        render_device_activation(
          { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE, expired_code: true },
          debug_reason: @device_auth_debug_reason || "device_code_unavailable",
        )
      end
      return
    end

    UserApiKey::DeviceAuth::Authorize.call(
      device_auth_service_params(device_code: device_code, user_id: current_user.id),
    ) do
      on_success do
        if params[:approval_token].present?
          device_user_activation.delete_approval_token(params[:approval_token])
        end
        render_device_activation(
          { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_COMPLETE, denied: false },
        )
      end
      on_model_not_found(:user) do
        trace_device_auth(
          "device_auth.authorize.failed",
          reason: "user_not_found",
          device_code: device_code,
        )
        raise Discourse::InvalidAccess
      end
      on_failed_step(:authorize_grant) do |failure|
        render_device_activation(
          { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE, expired_code: true },
          debug_reason: failure.error,
        )
      end
      on_exceptions(Discourse::InvalidParameters, Discourse::InvalidAccess) do |exception|
        trace_device_auth(
          "device_auth.authorize.failed",
          reason: exception.class.name,
          exception: exception,
          device_code: device_code,
        )
        raise exception
      end
    end
  end

  def deny_device_request
    if params[:request].present?
      render_device_activation(
        { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE, expired_code: true },
        debug_reason: "deny_requires_approval_token",
      )
      return
    end

    approval_token = params.require(:approval_token)
    result =
      device_user_activation.resolve_deny_device_code(
        request_token: nil,
        approval_token: approval_token,
      )

    if result.status != :success
      render_device_activation(
        { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE, expired_code: true },
        debug_reason: result.debug_reason,
      )
      return
    end

    UserApiKey::DeviceAuth::Deny.call(
      device_auth_service_params(device_code: result.device_code),
    ) do
      on_success do
        device_user_activation.delete_approval_token(approval_token)
        render_device_activation(
          { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_COMPLETE, denied: true },
        )
      end
      on_failed_step(:deny_grant) do |failure|
        render_device_activation(
          { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE, expired_code: true },
          debug_reason: failure.error,
        )
      end
      on_exceptions(Discourse::InvalidParameters, Discourse::InvalidAccess) do |exception|
        render_device_activation(
          { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE, expired_code: true },
          debug_reason: exception.class.name,
        )
      end
    end
  end

  def poll_device_request
    ensure_json_request!
    rate_limit_device_poll

    device_code = params.require(:device_code)
    rate_limit_device_poll_for_code(device_code)

    UserApiKey::DeviceAuth::Poll.call(device_auth_service_params(device_code: device_code)) do
      on_success { |poll_response:| render json: poll_response }
    end
  end

  def otp
    require_params_otp
    find_client_by_public_key
    validate_params_otp
    validate_auth_redirect

    unless current_user
      cookies[:destination_url] = request.fullpath

      if SiteSetting.enable_discourse_connect?
        redirect_to path("/session/sso")
      else
        redirect_to path("/login")
      end
      return
    end

    json = user_api_key_otp_model

    respond_to do |format|
      format.html do
        store_preloaded("user_api_key_otp", MultiJson.dump(json))
        raise ApplicationController::RenderEmpty.new
      end
      format.json { render json: json }
    end
  end

  def create_otp
    require_params_otp
    find_client_by_public_key
    validate_params_otp
    validate_auth_redirect

    raise Discourse::InvalidAccess unless meets_tl?

    otp_payload = one_time_password(parsed_public_key, current_user.username)
    redirect_path = "#{params[:auth_redirect]}?oneTimePassword=#{CGI.escape(otp_payload)}"

    respond_to do |format|
      format.html { redirect_to(redirect_path, allow_other_host: true) }
      format.json { render json: { redirect_url: redirect_path } }
    end
  end

  def revoke
    current_key = request.env["HTTP_USER_API_KEY"]

    revoke_key = find_key if params[:id]
    revoke_key ||= UserApiKey.with_key(current_key).first if current_key.present?

    raise Discourse::NotFound unless revoke_key

    revoke_key.update_columns(revoked_at: Time.zone.now)

    render json: success_json
  end

  def undo_revoke
    find_key.update_columns(revoked_at: nil)
    render json: success_json
  end

  def render_user_api_key_authorization(json)
    respond_to do |format|
      format.html do
        store_preloaded("user_api_key_authorization", MultiJson.dump(json))
        raise ApplicationController::RenderEmpty.new
      end
      format.json { render json: json }
    end
  end

  def render_device_activation(json, debug_reason: nil)
    if debug_reason.present?
      trace_device_auth(
        "device_auth.activation.rendered_generic",
        reason: debug_reason,
        state: json[:state] || json["state"],
        expired_code: json[:expired_code] || json["expired_code"],
        invalid_code: json[:invalid_code] || json["invalid_code"],
      )
    end

    respond_to do |format|
      format.html do
        store_preloaded("user_api_key_device_activation", MultiJson.dump(json))
        raise ApplicationController::RenderEmpty.new
      end
      format.json { render json: json }
    end
  end

  def user_api_key_authorization_model
    require_params
    find_client
    require_client_params
    validate_params
    validate_auth_redirect
    expires_in_seconds = parse_expires_in_seconds!

    unless current_user
      redirect_anonymous_to_login
      return
    end

    application_name = params[:application_name] || @client&.application_name
    scopes = params[:scopes]
    expires_at = requested_expires_at(expires_in_seconds)

    if !meets_tl?
      return(
        {
          state: UserApiKey::DeviceAuth::AUTHORIZATION_STATE_NO_TRUST_LEVEL,
          application_name: application_name,
          current_user: current_user_json,
        }
      )
    end

    {
      state: UserApiKey::DeviceAuth::AUTHORIZATION_STATE_READY,
      application_name: application_name,
      public_key: params[:public_key] || @client&.public_key,
      nonce: params[:nonce],
      client_id: params[:client_id],
      auth_redirect: params[:auth_redirect],
      redirect_uri: redirect_uri_for(params[:auth_redirect]),
      push_url: params[:push_url],
      localized_scopes: localized_scopes(scopes),
      scopes: scopes,
      write_scope: scopes.split(",").include?("write"),
      padding: params[:padding],
      expires_in_seconds: expires_in_seconds,
      expires_at: expires_at&.iso8601,
      current_user: current_user_json,
    }
  end

  def user_api_key_otp_model
    {
      application_name: params[:application_name],
      public_key: params[:public_key],
      auth_redirect: params[:auth_redirect],
      padding: params[:padding],
    }
  end

  def device_activation_model
    if params[:request].blank?
      return { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE }
    end

    rate_limit_device_request_token_lookup(params[:request])
    result = device_user_activation.preview_request_token(params[:request])

    if result.status != :success
      trace_device_auth(
        "device_auth.activation.preview.failed",
        reason: result.debug_reason,
        request_token: params[:request],
      )
      return(
        { state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_ENTER_CODE, expired_code: true }
      )
    end

    @device_auth = result.grant
    device_authorization_model(
      state: UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_AUTHORIZE,
      request_token: params[:request],
      no_trust_level: !meets_tl?,
    )
  end

  def device_authorization_model(
    state:,
    request_token: nil,
    approval_token: nil,
    no_trust_level: false,
    invalid_code: false
  )
    {
      state: state,
      request_token: request_token,
      approval_token: approval_token,
      no_trust_level: no_trust_level,
      invalid_code: invalid_code,
      device_auth: device_auth_json,
      current_user: current_user_json,
    }
  end

  def device_auth_json
    {
      application_name: @device_auth.application_name,
      localized_scopes: @device_auth.localized_scopes,
      write_scope: @device_auth.write_scope?,
      unregistered_client: @device_auth.unregistered_client?,
      expires_at: @device_auth.expires_at&.iso8601,
    }
  end

  def current_user_json
    return if current_user.blank?

    { username: current_user.username, avatar_template: current_user.avatar_template }
  end

  def redirect_uri_for(auth_redirect)
    return if auth_redirect.blank? || auth_redirect == "discourse://auth_redirect"

    uri = URI.parse(auth_redirect)
    if uri.port.nil? || [80, 443].include?(uri.port)
      uri.host
    else
      "#{uri.host}:#{uri.port}"
    end
  rescue StandardError
    nil
  end

  def localized_scopes(scopes)
    scopes.split(",").map { |scope| I18n.t("user_api_key.scopes.#{scope}") }
  end

  def find_key
    key = UserApiKey.find(params[:id])
    raise Discourse::InvalidAccess unless current_user.admin || key.user_id == current_user.id
    key
  end

  def find_client
    @client = UserApiKeyClient.find_by(client_id: params[:client_id])
  end

  def find_client_by_public_key
    @client = UserApiKeyClient.find_by(public_key: params[:public_key])
  end

  def require_params
    %i[nonce scopes client_id].each { |p| params.require(p) }
  end

  def require_client_params
    params.require(:public_key) if @client&.public_key.blank?
    params.require(:application_name) if @client&.application_name.blank?
  end

  def validate_params
    requested_scopes = Set.new(params[:scopes].split(","))
    raise Discourse::InvalidAccess unless UserApiKey.allowed_scopes.superset?(requested_scopes)
    if @client&.scopes.present? && !@client.allowed_scopes.superset?(requested_scopes)
      raise Discourse::InvalidAccess
    end

    parsed_public_key if public_key_str.present?
    validate_padding
  end

  def require_params_otp
    %i[public_key auth_redirect application_name].each { |p| params.require(p) }
  end

  def validate_params_otp
    parsed_public_key
    validate_padding
  end

  def validate_padding
    return if params[:padding].blank?
    return if ALLOWED_PADDING_MODES.include?(params[:padding])
    raise Discourse::InvalidParameters.new(:padding)
  end

  def validate_auth_redirect
    return unless params.key?(:auth_redirect)

    if @client&.auth_redirect.present? && params[:auth_redirect] != @client.auth_redirect
      raise Discourse::InvalidAccess
    end

    if UserApiKeyClient.invalid_auth_redirect?(params[:auth_redirect])
      raise Discourse::InvalidAccess
    end
  end

  def public_key_str
    @client&.public_key.presence || params[:public_key]
  end

  def parsed_public_key
    @parsed_public_key ||= parse_public_key!(public_key_str)
  end

  def parse_public_key!(value)
    UserApiKey::DeviceAuth::Crypto.parse_public_key!(value)
  end

  def meets_tl?
    current_user.staff? || current_user.in_any_groups?(SiteSetting.user_api_key_allowed_groups_map)
  end

  # `create` and `create_otp` are the only callers, and both respond in JSON
  # as well as HTML, so this is relied on by non-browser (API key/User API
  # key) consumers, not just browser sessions. Don't restrict this to
  # session auth without accounting for those consumers first.
  def one_time_password(public_key, username)
    unless UserApiKey.allowed_scopes.superset?(Set.new(["one_time_password"]))
      raise Discourse::InvalidAccess
    end

    otp = SecureRandom.hex
    Discourse.redis.setex "otp_#{otp}", 10.minutes, username

    Base64.encode64(
      UserApiKey::DeviceAuth::Crypto.encrypt!(public_key, otp, padding: params[:padding]),
    )
  end

  def parse_expires_in_seconds!
    UserApiKey::Expiry.parse_seconds!(params[:expires_in_seconds])
  end

  def requested_expires_at(expires_in_seconds)
    UserApiKey::Expiry.requested_expires_at(expires_in_seconds)
  end

  def ensure_json_request!
    raise Discourse::InvalidAccess unless request.format.json? && request.content_mime_type&.json?
  end

  def set_device_auth_no_store
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers["Referrer-Policy"] = "same-origin"
  end

  def redirect_anonymous_to_login(destination_url = request.fullpath)
    cookies[:destination_url] = destination_url

    if SiteSetting.enable_discourse_connect?
      redirect_to path("/session/sso")
    else
      redirect_to path("/login")
    end
  end

  def device_user_activation
    @device_user_activation ||=
      UserApiKey::DeviceAuth::UserActivation.new(
        session: session,
        user: current_user,
        request_id: request.request_id,
      )
  end

  def device_auth_service_params(**overrides)
    service_params.deep_merge(params: overrides, options: { request_id: request.request_id })
  end

  def trace_device_auth(event, **payload)
    UserApiKey::DeviceAuth.trace(
      event,
      **{ request_id: request.request_id, user_id: current_user&.id }.merge(payload),
    )
  end

  def device_code_for_authorize_request
    if params[:request].present?
      rate_limit_device_request_token_lookup(params[:request])
      preview = device_user_activation.preview_request_token(params[:request])
      if preview.status != :success
        @device_auth_debug_reason = preview.debug_reason
        return
      end

      @device_auth = preview.grant
      @request_token = params[:request]

      rate_limit_device_activation_attempt
      result =
        device_user_activation.resolve_authorize_device_code(
          request_token: params[:request],
          user_code: params[:code],
          approval_token: nil,
        )
      @device_auth = result.grant if result.grant.present?
      @device_auth_debug_reason = result.debug_reason

      return result.device_code if result.status == :success
      return
    end

    approval_token = params.require(:approval_token)
    result =
      device_user_activation.resolve_authorize_device_code(
        request_token: nil,
        user_code: nil,
        approval_token: approval_token,
      )
    @device_auth_debug_reason = result.debug_reason
    result.device_code if result.status == :success
  end

  def rate_limit_device_request_creation
    RateLimiter.new(
      nil,
      "user-api-key-device-requests-#{request.remote_ip}",
      DEVICE_REQUESTS_PER_MINUTE,
      1.minute,
    ).performed!
  end

  def rate_limit_device_poll
    RateLimiter.new(
      nil,
      "user-api-key-device-poll-ip-#{request.remote_ip}",
      DEVICE_POLLS_PER_MINUTE,
      1.minute,
    ).performed!
  end

  def rate_limit_device_poll_for_code(device_code)
    RateLimiter.new(
      nil,
      "user-api-key-device-poll-code-#{ApiKey.hash_key(device_code)}",
      DEVICE_POLLS_PER_MINUTE,
      1.minute,
    ).performed!
  end

  def rate_limit_device_request_token_lookup(request_token)
    token_key =
      (
        if UserApiKey::DeviceAuth::CodeRegistry.valid_request_token?(request_token)
          ApiKey.hash_key(request_token)
        else
          "invalid"
        end
      )
    RateLimiter.new(
      nil,
      "user-api-key-device-request-token-ip-#{request.remote_ip}",
      DEVICE_REQUEST_TOKEN_LOOKUPS_PER_HOUR,
      1.hour,
    ).performed!
    RateLimiter.new(
      nil,
      "user-api-key-device-request-token-user-#{current_user.id}",
      DEVICE_REQUEST_TOKEN_LOOKUPS_PER_MINUTE,
      1.minute,
    ).performed!
    RateLimiter.new(
      nil,
      "user-api-key-device-request-token-#{token_key}",
      DEVICE_REQUEST_TOKEN_LOOKUPS_PER_MINUTE,
      1.minute,
    ).performed!
  end

  def rate_limit_device_activation_attempt
    normalized_code =
      UserApiKey::DeviceAuth::CodeRegistry.normalize_user_code(params[:code]) || "invalid"
    RateLimiter.new(
      nil,
      "user-api-key-device-activate-ip-#{request.remote_ip}",
      DEVICE_ACTIVATION_ATTEMPTS_PER_HOUR,
      1.hour,
    ).performed!
    RateLimiter.new(
      nil,
      "user-api-key-device-activate-user-#{current_user.id}",
      DEVICE_ACTIVATION_ATTEMPTS_PER_MINUTE,
      1.minute,
    ).performed!
    RateLimiter.new(
      nil,
      "user-api-key-device-activate-code-#{ApiKey.hash_key(normalized_code)}",
      DEVICE_ACTIVATION_ATTEMPTS_PER_MINUTE,
      1.minute,
    ).performed!
  end
end
