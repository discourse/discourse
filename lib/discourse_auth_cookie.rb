# frozen_string_literal: true

# You may have seen references to v0 and v1 of our auth cookie in the codebase
# and you're not sure how they differ, so here is an explanation:
#
# From the very early days of Discourse, the auth cookie (_t) consisted only of
# a 32 characters random string that Discourse used to identify/lookup the
# current user. We didn't include any metadata with the cookie or encrypt/sign
# it.
#
# That was v0 of the auth cookie until Nov 2021 when we merged a change that
# required us to store additional metadata with the cookie so we could get more
# information about current user early in the request lifecycle before we
# performed database lookup. We also started encrypting and signing the cookie
# to prevent tampering and obfuscate user information that we include in the
# cookie. This is v1 of our auth cookie and we still use it to this date.
#
# We still accept v0 of the auth cookie to keep users logged in, but upon
# cookie rotation (which happen every 10 minutes) they'll be switched over to
# the v1 format.
#
# We'll drop support for v0 after Discourse 2.9 is released.

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
        db_name = RailsMultisite::ConnectionManagement.current_db
        key = Rails.application.key_generator.generate_key("discourse-auth-cookie-#{db_name}", 32)
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
  ISSUED_AT_KEY = "issued_at"
  private_constant *%i[
    TOKEN_KEY
    USER_ID_KEY
    USER_TRUST_LEVEL_KEY
    ISSUED_AT_KEY
  ]

  attr_reader :token, :user_id, :trust_level, :issued_at

  def self.parse(raw_cookie)
    # v0 of the cookie was simply the auth token itself. we need this for
    # backward compatibility so we don't wipe out existing sessions.
    # TODO: drop this line after the 2.9 release
    return new(token: raw_cookie) if raw_cookie.size == TOKEN_SIZE

    data = Encryptor.new.decrypt_and_verify(raw_cookie)

    token = nil
    user_id = nil
    trust_level = nil
    issued_at = nil

    data.split(",").each do |part|
      prefix, val = part.split(":", 2)
      val = val.presence
      if prefix == TOKEN_KEY
        token = val
      elsif prefix == USER_ID_KEY
        user_id = val
      elsif prefix == USER_TRUST_LEVEL_KEY
        trust_level = val
      elsif prefix == ISSUED_AT_KEY
        issued_at = val
      end
    end

    new(
      token: token,
      user_id: user_id,
      trust_level: trust_level,
      issued_at: issued_at
    )
  end

  def initialize(token:, user_id: nil, trust_level: nil, issued_at: nil)
    @token = token
    @user_id = user_id.to_i if user_id
    @trust_level = trust_level.to_i if trust_level
    @issued_at = issued_at.to_i if issued_at
    validate!
  end

  def serialize
    parts = []
    parts << "#{TOKEN_KEY}:#{token}"
    parts << "#{USER_ID_KEY}:#{user_id}"
    parts << "#{USER_TRUST_LEVEL_KEY}:#{trust_level}"
    parts << "#{ISSUED_AT_KEY}:#{issued_at}"
    data = parts.join(",")
    Encryptor.new.encrypt_and_sign(data)
  end

  private

  def validate!
    validate_token!
  end

  def validate_token!
    raise InvalidCookie.new if token.blank? || token.size != TOKEN_SIZE
  end
end
