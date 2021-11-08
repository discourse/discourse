# frozen_string_literal: true

class DiscourseAuthCookie
  class InvalidCookie < StandardError; end

  class Encryptor
    def encrypt_and_sign(plain_cookie)
      encryptor.encrypt_and_sign(plain_cookie)
    end

    def decrypt_and_verify(cipher_cookie)
      encryptor.decrypt_and_verify(cipher_cookie)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise InvalidCookie.new
    end

    private

    def encryptor
      @encryptor ||= begin
        key = Rails.application.key_generator.generate_key("discourse-auth-cookie", 32)
        ActiveSupport::MessageEncryptor.new(
          key,
          key,
          cipher: "aes-256-cbc",
          digest: "SHA256"
        )
      end
    end
  end

  TOKEN_SIZE = 32

  TOKEN_KEY = "token"
  USER_ID_KEY = "id"
  USER_TRUST_LEVEL_KEY = "tl"
  TIME_KEY = "time"
  VALID_KEY = "valid"
  private_constant *%i[
    TOKEN_KEY
    USER_ID_KEY
    USER_TRUST_LEVEL_KEY
    TIME_KEY
    VALID_KEY
  ]

  attr_reader :token, :user_id, :trust_level, :timestamp, :valid_for

  def self.parse(raw_cookie)
    # v0 of the cookie was simply the auth token itself. we need
    # this for backward compatibility so we don't wipe out existing
    # sessions.  TODO: drop this line (and a test case in
    # default_current_user_provider_spec.rb) after the 3.0 release
    return new(token: raw_cookie) if raw_cookie.size == TOKEN_SIZE

    data = Encryptor.new.decrypt_and_verify(raw_cookie)

    token = nil
    user_id = nil
    trust_level = nil
    timestamp = nil
    valid_for = nil

    data.split(",").each do |part|
      prefix, val = part.split(":", 2)
      val = val.presence
      if prefix == TOKEN_KEY
        token = val
      elsif prefix == USER_ID_KEY
        user_id = val
      elsif prefix == USER_TRUST_LEVEL_KEY
        trust_level = val
      elsif prefix == TIME_KEY
        timestamp = val
      elsif prefix == VALID_KEY
        valid_for = val
      end
    end

    new(
      token: token,
      user_id: user_id,
      trust_level: trust_level,
      timestamp: timestamp,
      valid_for: valid_for,
    )
  end

  def initialize(token:, user_id: nil, trust_level: nil, timestamp: nil, valid_for: nil)
    @token = token
    @user_id = user_id.to_i if user_id
    @trust_level = trust_level.to_i if trust_level
    @timestamp = timestamp.to_i if timestamp
    @valid_for = valid_for.to_i if valid_for
  end

  def serialize
    parts = []
    parts << "#{TOKEN_KEY}:#{token}"
    parts << "#{USER_ID_KEY}:#{user_id}"
    parts << "#{USER_TRUST_LEVEL_KEY}:#{trust_level}"
    parts << "#{TIME_KEY}:#{timestamp}"
    parts << "#{VALID_KEY}:#{valid_for}"
    data = parts.join(",")
    Encryptor.new.encrypt_and_sign(data)
  end

  def validate!(validate_age: true)
    validate_token!
    validate_age! if validate_age
  end

  private

  def validate_token!
    raise InvalidCookie.new if token.blank? || token.size != TOKEN_SIZE
  end

  def validate_age!
    return if !(valid_for && timestamp)
    if timestamp + valid_for < Time.zone.now.to_i
      raise InvalidCookie.new
    end
  end
end
