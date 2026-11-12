# frozen_string_literal: true

require "digest"

class UserApiKey::DeviceAuth
  # Device auth flow:
  #
  # 1. A client POSTs to `/user-api-key/device.json`.
  #    `CreateRequest` validates the request, stores a short-lived pending grant in Redis, and
  #    returns a device code, a user-facing code, and an 8-character request token.
  # 2. The user visits `/user-api-key/activate` manually, or opens the request-token URL.
  #    `UserActivation` loads the pending grant and validates user-facing codes/tokens.
  # 3. The user confirms the code. Manual-code approvals bind the pending grant to the
  #    approving user and receive a browser-session approval token. Request-token approvals
  #    bind the pending grant to the approving user after a matching code is submitted.
  # 4. `Authorize` creates the User API key, encrypts the response payload, stores it briefly,
  #    and removes the user-code/request-token indexes.
  # 5. The client polls until `Poll` returns pending, denied, expired, or the encrypted payload.
  AUTH_API_VERSION = UserApiKeysController::AUTH_API_VERSION
  ALLOWED_PADDING_MODES = UserApiKeysController::ALLOWED_PADDING_MODES
  DEVICE_AUTH_TTL = 10.minutes
  DEVICE_AUTH_INTERVAL = 5
  DEVICE_AUTHORIZED_PAYLOAD_TTL = 1.minute
  DEVICE_KEY_PLACEHOLDER = "x" * 32
  DEVICE_CODE_REDIS_PREFIX = "user_api_key:device:"
  DEVICE_USER_CODE_REDIS_PREFIX = "user_api_key:device:code:"
  DEVICE_REQUEST_REDIS_PREFIX = "user_api_key:device:request:"
  DEVICE_AUTHORIZATION_LOCK_REDIS_PREFIX = "user_api_key:device:lock:"
  USER_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  DEVICE_CODE_REGEX = /\A\h{64}\z/
  DEVICE_REQUEST_TOKEN_REGEX = /\A[-_A-Za-z0-9]{8}\z/
  DISALLOWED_DEVICE_SCOPES = Set.new(%w[one_time_password])
  MAX_DEVICE_CLIENT_ID_LENGTH = 200
  MAX_DEVICE_APPLICATION_NAME_LENGTH = 200
  MAX_DEVICE_NONCE_LENGTH = 256
  MAX_DEVICE_PUBLIC_KEY_LENGTH = 4096
  MAX_DEVICE_PUSH_URL_LENGTH = 2000
  MAX_DEVICE_SCOPES_LENGTH = 500
  MAX_DEVICE_SCOPES_COUNT = 20
  MAX_DEVICE_GRANT_BYTES = 10_000
  MAX_CODE_REGISTRY_COLLISION_ATTEMPTS = 20
  MIN_DEVICE_RSA_BITS = 2048
  MAX_DEVICE_RSA_BITS = 8192
  DEVICE_AUTHORIZATION_LOCK_TTL = 30.seconds

  AUTHORIZATION_STATE_READY = "ready"
  AUTHORIZATION_STATE_NO_TRUST_LEVEL = "no_trust_level"
  AUTHORIZATION_STATE_GENERIC_ERROR = "generic_error"
  DEVICE_ACTIVATION_STATE_ENTER_CODE = "enter_code"
  DEVICE_ACTIVATION_STATE_AUTHORIZE = "authorize"
  DEVICE_ACTIVATION_STATE_COMPLETE = "complete"
  POLL_STATUS_AUTHORIZATION_PENDING = "authorization_pending"
  POLL_STATUS_AUTHORIZED = "authorized"
  POLL_STATUS_ACCESS_DENIED = "access_denied"
  POLL_STATUS_EXPIRED_TOKEN = "expired_token"

  # Response contracts consumed by the Ember UI and CLI poller. Keep this table in sync with
  # `frontend/discourse/app/lib/user-api-key-device-auth.js` when adding states/statuses.
  AUTHORIZATION_STATE_CONTRACT = {
    AUTHORIZATION_STATE_READY => {
      description: "Show the key authorization confirmation UI.",
      required_fields: %i[
        application_name
        client_id
        current_user
        localized_scopes
        nonce
        public_key
        scopes
        write_scope
      ],
      optional_fields: %i[
        auth_redirect
        expires_at
        expires_in_seconds
        padding
        push_url
        redirect_uri
      ],
    },
    AUTHORIZATION_STATE_NO_TRUST_LEVEL => {
      description: "Show a signed-in user that their account cannot create user API keys.",
      required_fields: %i[application_name current_user],
    },
    AUTHORIZATION_STATE_GENERIC_ERROR => {
      description: "Show a generic, user-safe authorization error.",
      required_fields: [],
    },
  }.freeze

  DEVICE_ACTIVATION_STATE_CONTRACT = {
    DEVICE_ACTIVATION_STATE_ENTER_CODE => {
      description:
        "Show manual code entry; optional invalid_code/expired_code flags explain UI copy.",
      required_fields: [],
      optional_fields: %i[invalid_code expired_code],
    },
    DEVICE_ACTIVATION_STATE_AUTHORIZE => {
      description: "Show the approval UI for a loaded pending grant.",
      required_fields: %i[current_user device_auth],
      optional_fields: %i[approval_token invalid_code no_trust_level request_token],
    },
    DEVICE_ACTIVATION_STATE_COMPLETE => {
      description: "Show the terminal browser result after authorize/deny.",
      required_fields: %i[denied],
    },
  }.freeze

  POLL_STATUS_CONTRACT = {
    POLL_STATUS_AUTHORIZATION_PENDING =>
      "The grant is still pending, or an authorized payload is briefly locked.",
    POLL_STATUS_AUTHORIZED => "The response includes the encrypted payload and consumes the grant.",
    POLL_STATUS_ACCESS_DENIED => "The user denied the grant.",
    POLL_STATUS_EXPIRED_TOKEN =>
      "The code is invalid, expired, missing, already consumed, or otherwise unavailable.",
  }.freeze

  TRACE_EVENT = :user_api_key_device_auth_trace
  TRACE_HASH_LENGTH = 12
  TRACE_HASH_KEYS = %i[approval_token device_code request_token user_code].freeze
  TRACE_FILTERED_KEYS = %i[key nonce payload public_key].freeze
  TRACE_MAX_VALUE_LENGTH = 256

  def self.clear!
    UserApiKey::DeviceAuth::GrantStore.clear!
    UserApiKey::DeviceAuth::CodeRegistry.clear!
  end

  def self.trace(event, **payload)
    event = event.to_s
    payload = normalize_trace_payload(payload)

    DiscourseEvent.trigger(TRACE_EVENT, event, payload, continue_on_error: true)

    return if !SiteSetting.verbose_user_api_key_device_auth_logging

    Rails.logger.info({ message: "user_api_key.device_auth", event: event }.merge(payload).to_json)
  rescue StandardError => exception
    Discourse.warn_exception(
      exception,
      message: "User API key device auth trace failed",
      env: {
        event: event,
      },
    )
    nil
  end

  def self.trace_id_for(value)
    return if value.nil? || value.to_s.empty?

    Digest::SHA256.hexdigest(value.to_s)[0, TRACE_HASH_LENGTH]
  end

  def self.normalize_trace_payload(payload)
    payload.each_with_object({}) do |(key, value), sanitized|
      key = key.to_sym
      next if value.nil? || (value.respond_to?(:empty?) && value.empty?)

      if TRACE_HASH_KEYS.include?(key)
        sanitized[:"#{key}_hash"] = trace_id_for(value)
      elsif TRACE_FILTERED_KEYS.include?(key)
        sanitized[:"#{key}_present"] = true
      elsif value.is_a?(Exception)
        sanitized[:exception_class] = value.class.name
      elsif value.respond_to?(:iso8601)
        sanitized[key] = value.iso8601
      elsif value.is_a?(String)
        sanitized[key] = value.first(TRACE_MAX_VALUE_LENGTH)
      else
        sanitized[key] = value
      end
    end
  end
  private_class_method :normalize_trace_payload
end
