# frozen_string_literal: true

class UserApiKey::DeviceAuth::CodeRegistry
  USER_CODE_ALPHABET = UserApiKey::DeviceAuth::USER_CODE_ALPHABET
  REQUEST_TOKEN_REGEX = UserApiKey::DeviceAuth::DEVICE_REQUEST_TOKEN_REGEX
  MAX_COLLISION_ATTEMPTS = UserApiKey::DeviceAuth::MAX_CODE_REGISTRY_COLLISION_ATTEMPTS

  CodeSet =
    if const_defined?(:CodeSet, false)
      const_get(:CodeSet)
    else
      Struct.new(:user_code, :request_token, keyword_init: true)
    end

  def self.valid_request_token?(request_token)
    REQUEST_TOKEN_REGEX.match?(request_token.to_s)
  end

  def self.normalize_user_code(value)
    code = value.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    return if code.length != 8

    "#{code[0, 4]}-#{code[4, 4]}"
  end

  def self.reserve_for(device_code)
    request_token = nil
    user_code = nil

    begin
      request_token = reserve_request_token!(device_code)
      user_code = reserve_user_code!(device_code)

      CodeSet.new(user_code: user_code, request_token: request_token)
    rescue StandardError
      delete_request_token(request_token) if request_token.present?
      delete_user_code(user_code) if user_code.present?
      raise
    end
  end

  def self.load_by_user_code(user_code)
    device_code = Discourse.redis.get(user_code_key(user_code))
    return if device_code.blank?

    grant = UserApiKey::DeviceAuth::GrantStore.load(device_code)
    delete_user_code(user_code) if grant.blank?
    grant
  end

  def self.load_by_request_token(request_token)
    return if !valid_request_token?(request_token)

    device_code = Discourse.redis.get(request_token_key(request_token))
    return if device_code.blank?

    grant = UserApiKey::DeviceAuth::GrantStore.load(device_code)
    delete_request_token(request_token) if grant.blank?
    grant
  end

  def self.user_code_matches_grant?(user_code, grant)
    normalized_code = normalize_user_code(user_code)
    return false if normalized_code.blank?

    device_code = Discourse.redis.get(user_code_key(normalized_code))
    device_code.present? && device_code == grant.device_code
  end

  def self.delete_indexes_for(grant)
    delete_user_code(grant.user_code) if grant.user_code.present?
    delete_request_token(grant.request_token) if grant.request_token.present?
  end

  def self.delete_user_code(user_code)
    Discourse.redis.del(user_code_key(user_code))
  end

  def self.delete_request_token(request_token)
    Discourse.redis.del(request_token_key(request_token))
  end

  def self.user_code_key(user_code)
    "#{UserApiKey::DeviceAuth::DEVICE_USER_CODE_REDIS_PREFIX}#{user_code}"
  end

  def self.request_token_key(request_token)
    "#{UserApiKey::DeviceAuth::DEVICE_REQUEST_REDIS_PREFIX}#{request_token}"
  end

  def self.clear!
    [
      UserApiKey::DeviceAuth::DEVICE_USER_CODE_REDIS_PREFIX,
      UserApiKey::DeviceAuth::DEVICE_REQUEST_REDIS_PREFIX,
    ].each do |prefix|
      Discourse.redis.scan_each(match: "#{prefix}*") { |key| Discourse.redis.del(key) }
    end
  end

  def self.reserve_user_code!(device_code)
    MAX_COLLISION_ATTEMPTS.times do
      user_code = generate_user_code
      if Discourse.redis.set(
           user_code_key(user_code),
           device_code,
           nx: true,
           ex: UserApiKey::DeviceAuth::DEVICE_AUTH_TTL.to_i,
         )
        return user_code
      end
    end

    raise Discourse::InvalidAccess
  end

  def self.reserve_request_token!(device_code)
    MAX_COLLISION_ATTEMPTS.times do
      request_token = SecureRandom.urlsafe_base64(6)
      if Discourse.redis.set(
           request_token_key(request_token),
           device_code,
           nx: true,
           ex: UserApiKey::DeviceAuth::DEVICE_AUTH_TTL.to_i,
         )
        return request_token
      end
    end

    raise Discourse::InvalidAccess
  end

  def self.generate_user_code
    code =
      Array
        .new(8) { USER_CODE_ALPHABET[SecureRandom.random_number(USER_CODE_ALPHABET.length)] }
        .join
    "#{code[0, 4]}-#{code[4, 4]}"
  end
  private_class_method :reserve_user_code!, :reserve_request_token!, :generate_user_code
end
