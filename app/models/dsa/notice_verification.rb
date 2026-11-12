# frozen_string_literal: true

module Dsa
  class NoticeVerification
    VALID_FOR = 30.minutes

    def self.create(email)
      token = SecureRandom.hex(32)
      code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
      Discourse.redis.setex(key(token), VALID_FOR.to_i, { email:, code: }.to_json)
      token
    end

    def self.find(token)
      value = Discourse.redis.get(key(token))
      JSON.parse(value, symbolize_names: true) if value
    end

    def self.verify(token:, email:, code:)
      verification = find(token)
      return unless verification && verification[:code]

      RateLimiter.new(nil, "dsa-notice-verification-attempts-#{token}", 5, VALID_FOR).performed!
      unless verification[:email] == email &&
               ActiveSupport::SecurityUtils.secure_compare(verification[:code], code)
        return
      end

      saved =
        Discourse.redis.set(key(token), { email:, verified: true }.to_json, xx: true, keepttl: true)
      { email: } if saved
    end

    def self.consume(token:, email:)
      verification = find(token)
      return unless verification && verification[:verified] && verification[:email] == email

      value = Discourse.redis.getdel(key(token))
      JSON.parse(value, symbolize_names: true).except(:verified) if value
    end

    def self.key(token)
      "dsa-notice-verification:#{token}"
    end
    private_class_method :key
  end
end
