# frozen_string_literal: true

class UserApiKey::DeviceAuth::RequestValidator
  ALLOWED_PADDING_MODES = UserApiKey::DeviceAuth::ALLOWED_PADDING_MODES
  DISALLOWED_DEVICE_SCOPES = UserApiKey::DeviceAuth::DISALLOWED_DEVICE_SCOPES
  MAX_DEVICE_CLIENT_ID_LENGTH = UserApiKey::DeviceAuth::MAX_DEVICE_CLIENT_ID_LENGTH
  MAX_DEVICE_APPLICATION_NAME_LENGTH = UserApiKey::DeviceAuth::MAX_DEVICE_APPLICATION_NAME_LENGTH
  MAX_DEVICE_NONCE_LENGTH = UserApiKey::DeviceAuth::MAX_DEVICE_NONCE_LENGTH
  MAX_DEVICE_PUBLIC_KEY_LENGTH = UserApiKey::DeviceAuth::MAX_DEVICE_PUBLIC_KEY_LENGTH
  MAX_DEVICE_PUSH_URL_LENGTH = UserApiKey::DeviceAuth::MAX_DEVICE_PUSH_URL_LENGTH
  MAX_DEVICE_SCOPES_LENGTH = UserApiKey::DeviceAuth::MAX_DEVICE_SCOPES_LENGTH
  MAX_DEVICE_SCOPES_COUNT = UserApiKey::DeviceAuth::MAX_DEVICE_SCOPES_COUNT
  MIN_DEVICE_RSA_BITS = UserApiKey::DeviceAuth::MIN_DEVICE_RSA_BITS
  MAX_DEVICE_RSA_BITS = UserApiKey::DeviceAuth::MAX_DEVICE_RSA_BITS

  def self.validate!(params, client)
    validate_param_lengths!(params)

    if (client.blank? || client.application_name.blank?) && params[:application_name].blank?
      raise Discourse::InvalidParameters.new(:application_name)
    end

    scopes = params[:scopes].split(",")
    validate_requested_scopes!(scopes)
    validate_client_scopes!(client, scopes)
    validate_padding!(params[:padding])
    validate_public_key_constraints!(
      UserApiKey::DeviceAuth::Crypto.parse_public_key!(public_key_str(params, client)),
    )
  end

  def self.public_key_str(params, client)
    client&.public_key.presence || params[:public_key]
  end

  def self.validate_requested_scopes!(scopes)
    raise Discourse::InvalidParameters.new(:scopes) if scopes.blank? || scopes.any?(&:blank?)

    requested_scopes = Set.new(scopes)
    if DISALLOWED_DEVICE_SCOPES.intersect?(requested_scopes)
      raise Discourse::InvalidParameters.new(:scopes)
    end
    raise Discourse::InvalidAccess if !UserApiKey.allowed_scopes.superset?(requested_scopes)
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

  def self.validate_param_lengths!(params)
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
  private_class_method :validate_param_length!
end
