# frozen_string_literal: true

module Dsa
  class NoticeRateLimiter
    MAX_REQUESTS_PER_REPORTER_PER_DAY = 3

    def self.perform(email:, ip_address:, user_id: nil)
      prefix = user_id ? "dsa-notice-submission" : "dsa-notice"
      if ip_address.present?
        RateLimiter.new(nil, "#{prefix}-ip-#{ip_address}", 5, 1.hour).performed!
      end
      reporter_key = user_id ? "user-#{user_id}" : "email-#{Digest::SHA256.hexdigest(email)}"
      reporter_limiter =
        RateLimiter.new(nil, "#{prefix}-#{reporter_key}", MAX_REQUESTS_PER_REPORTER_PER_DAY, 1.day)
      reporter_limiter.performed!
      begin
        RateLimiter.new(nil, "#{prefix}-global", 100, 1.hour).performed!
      rescue RateLimiter::LimitExceeded
        reporter_limiter.rollback!
        raise
      end
    end
  end
end
