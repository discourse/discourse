# frozen_string_literal: true

class UserApiKey::DeviceAuth
  # Device auth flow:
  #
  # 1. A client POSTs to `/user-api-key/device.json`.
  #    `CreateRequest` validates the request, stores a short-lived pending grant in Redis, and
  #    returns a device code, a user-facing code, and an 8-character request token.
  # 2. The user visits `/user-api-key/activate` manually, or opens the request-token URL.
  #    The controller loads the pending grant and renders the approval UI.
  # 3. The user confirms the code. Manual-code approvals receive a browser-session approval
  #    token. Request-token approvals bind the pending grant to the approving user after a
  #    matching code is submitted.
  # 4. `Authorize` creates the User API key, encrypts the response payload, stores it briefly,
  #    and removes the user-code/request-token indexes.
  # 5. The client polls until `Poll` returns pending, denied, expired, or the encrypted payload.
  AUTH_API_VERSION = UserApiKeysController::AUTH_API_VERSION
  ALLOWED_PADDING_MODES = UserApiKeysController::ALLOWED_PADDING_MODES
  DEVICE_AUTH_TTL = 10.minutes
  DEVICE_AUTH_INTERVAL = 5
  DEVICE_AUTHORIZED_PAYLOAD_TTL = 1.minute
  DEVICE_KEY_PLACEHOLDER = "x" * 32
  DEVICE_CODE_REDIS_PREFIX = "user_api_key:device:".freeze
  DEVICE_USER_CODE_REDIS_PREFIX = "user_api_key:device:code:".freeze
  DEVICE_REQUEST_REDIS_PREFIX = "user_api_key:device:request:".freeze
  DEVICE_AUTHORIZATION_LOCK_REDIS_PREFIX = "user_api_key:device:lock:".freeze
  USER_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".freeze
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
  MIN_DEVICE_RSA_BITS = 2048
  MAX_DEVICE_RSA_BITS = 8192
  DEVICE_AUTHORIZATION_LOCK_TTL = 30.seconds

  def self.valid_request_token?(request_token)
    DEVICE_REQUEST_TOKEN_REGEX.match?(request_token.to_s)
  end

  def self.normalize_user_code(value)
    code = value.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    return if code.length != 8

    "#{code[0, 4]}-#{code[4, 4]}"
  end

  def self.bind_loaded_grant_to_user!(grant, user)
    return false if grant_bound_to_another_user?(grant, user)
    return true if grant_authorized_for_user?(grant, user)

    grant["authorizing_user_id"] = user.id
    grant["authorizing_username"] = user.username
    grant["authorizing_at"] = Time.zone.now.iso8601
    Store.save!(grant["device_code"], grant, ttl: Store.ttl_for_update(grant["device_code"]))
    true
  end

  def self.grant_bound_to_another_user?(grant, user)
    grant["authorizing_user_id"].present? && grant["authorizing_user_id"] != user.id
  end

  def self.grant_authorized_for_user?(grant, user)
    grant["authorizing_user_id"] == user.id
  end

  def self.parse_expires_in_seconds!(value)
    return if value.blank?

    seconds = Integer(value.to_s, 10)
    max_seconds = SiteSetting.max_user_api_key_expiry_days.to_i.days.to_i

    if seconds <= 0 || max_seconds <= 0 || seconds > max_seconds
      raise Discourse::InvalidParameters.new(:expires_in_seconds)
    end

    seconds
  rescue ArgumentError, TypeError
    raise Discourse::InvalidParameters.new(:expires_in_seconds)
  end

  def self.requested_expires_at(expires_in_seconds)
    expires_in_seconds.present? ? Time.zone.now + expires_in_seconds.to_i.seconds : nil
  end

  def self.public_key_str(params, client)
    client&.public_key.presence || params[:public_key]
  end

  def self.generate_user_code
    code =
      Array
        .new(8) { USER_CODE_ALPHABET[SecureRandom.random_number(USER_CODE_ALPHABET.length)] }
        .join
    "#{code[0, 4]}-#{code[4, 4]}"
  end

  def self.create_user_api_key_payload_from_grant!(grant, user)
    validate_grant!(grant)

    UserApiKey.transaction do
      client = UserApiKeyClient.find_by(client_id: grant["client_id"])
      client = UserApiKeyClient.new(client_id: grant["client_id"]) if client.blank?
      client.application_name = grant["application_name"] if client.new_record?
      client.save! if client.new_record? || client.changed?

      client.keys.where(user_id: user.id).destroy_all
      key =
        client.keys.create!(
          user_id: user.id,
          push_url: grant["push_url"],
          expires_at: requested_expires_at(grant["expires_in_seconds"]),
          scopes: grant["scopes"].map { |name| UserApiKeyScope.new(name: name) },
        )

      encrypted_payload_for_grant!(grant, key)
    end
  end

  def self.validate_request!(params, client)
    validate_request_param_lengths!(params)

    if (client.blank? || client.application_name.blank?) && params[:application_name].blank?
      raise Discourse::InvalidParameters.new(:application_name)
    end

    scopes = params[:scopes].split(",")
    validate_requested_scopes!(scopes)
    validate_client_scopes!(client, scopes)
    validate_padding!(params[:padding])
    validate_public_key_constraints!(Crypto.parse_public_key!(public_key_str(params, client)))
  end

  def self.validate_grant!(grant)
    requested_scopes = Set.new(grant["scopes"])
    raise Discourse::InvalidAccess unless UserApiKey.allowed_scopes.superset?(requested_scopes)
    validate_requested_scopes!(grant["scopes"])

    client = UserApiKeyClient.find_by(client_id: grant["client_id"])
    validate_client_scopes!(client, grant["scopes"])

    public_key = Crypto.parse_public_key!(grant["public_key"])
    validate_public_key_constraints!(public_key)
    validate_padding!(grant["padding"])
    validate_payload_size!(grant)
    validate_grant_size!(grant)
  end

  def self.validate_payload_size!(grant)
    payload = payload_for_grant(grant, key_value: DEVICE_KEY_PLACEHOLDER, push: false)
    Crypto.validate_payload_size!(
      payload,
      Crypto.parse_public_key!(grant["public_key"]),
      padding: grant["padding"],
    )
  end

  def self.payload_for_grant(grant, key_value:, push:)
    payload = { key: key_value, nonce: grant["nonce"], push: push, api: AUTH_API_VERSION }
    payload[:expires_at] = requested_expires_at(grant["expires_in_seconds"]).iso8601 if grant[
      "expires_in_seconds"
    ].present?
    payload.to_json
  end

  def self.encrypted_payload_for_grant!(grant, key)
    public_key = Crypto.parse_public_key!(grant["public_key"])
    payload = payload_for_grant(grant, key_value: key.key, push: key.has_push?)

    Crypto.validate_payload_size!(payload, public_key, padding: grant["padding"])
    Base64.encode64(Crypto.encrypt!(public_key, payload, padding: grant["padding"]))
  end

  def self.build_grant(params, client, scopes, expires_in_seconds, device_code)
    {
      status: "pending",
      device_code: device_code,
      application_name:
        if client.present?
          client.application_name.presence || params[:application_name]
        else
          params[:application_name]
        end,
      client_id: params[:client_id],
      public_key: public_key_str(params, client),
      nonce: params[:nonce],
      scopes: scopes,
      push_url: params[:push_url].presence,
      padding: params[:padding].presence,
      expires_in_seconds: expires_in_seconds,
      unregistered_client: client.blank? || client.public_key.blank?,
      created_at: Time.zone.now.iso8601,
    }.stringify_keys
  end

  def self.validate_request_param_lengths!(params)
    validate_param_length!(params, :client_id, MAX_DEVICE_CLIENT_ID_LENGTH)
    validate_param_length!(params, :application_name, MAX_DEVICE_APPLICATION_NAME_LENGTH)
    validate_param_length!(params, :nonce, MAX_DEVICE_NONCE_LENGTH)
    if params[:public_key].present?
      validate_param_length!(params, :public_key, MAX_DEVICE_PUBLIC_KEY_LENGTH)
    end
    if params[:push_url].present?
      validate_param_length!(params, :push_url, MAX_DEVICE_PUSH_URL_LENGTH)
    end

    scopes = params[:scopes].to_s
    if scopes.length > MAX_DEVICE_SCOPES_LENGTH ||
         scopes.split(",").length > MAX_DEVICE_SCOPES_COUNT
      raise Discourse::InvalidParameters.new(:scopes)
    end
  end

  def self.validate_param_length!(params, param_name, max_length)
    value = params[param_name]
    return if value.blank?
    raise Discourse::InvalidParameters.new(param_name) if value.to_s.bytesize > max_length
  end

  def self.validate_requested_scopes!(scopes)
    if scopes.blank? || scopes.any?(&:blank?) ||
         !UserApiKey.allowed_scopes.superset?(Set.new(scopes)) ||
         DISALLOWED_DEVICE_SCOPES.intersect?(Set.new(scopes))
      raise Discourse::InvalidParameters.new(:scopes)
    end
  end

  def self.validate_client_scopes!(client, scopes)
    if client&.scopes.present? && !client.allowed_scopes.superset?(Set.new(scopes))
      raise Discourse::InvalidAccess
    end
  end

  def self.validate_padding!(padding)
    return if padding.blank? || ALLOWED_PADDING_MODES.include?(padding)

    raise Discourse::InvalidParameters.new(:padding)
  end

  def self.validate_public_key_constraints!(public_key)
    bits = public_key.n.num_bits
    if bits < MIN_DEVICE_RSA_BITS || bits > MAX_DEVICE_RSA_BITS
      raise Discourse::InvalidParameters.new(:public_key)
    end
  end

  def self.validate_grant_size!(grant)
    raise Discourse::InvalidParameters.new(:base) if grant.to_json.bytesize > MAX_DEVICE_GRANT_BYTES
  end
end
