# frozen_string_literal: true

require "digest"

class GithubRateLimit
  KEY_PREFIX = "onebox_github_backoff_"
  MAX_SECONDS = 1.hour.to_i

  class << self
    def backing_off?(token = nil)
      redis.get(key(token)).present?
    end

    def active?
      redis.scan_each(match: "#{KEY_PREFIX}*").first.present?
    end

    def note_rate_limit(token: nil, retry_after: nil, remaining: nil, reset_at: nil)
      seconds =
        if retry_after.present?
          retry_after.to_i
        elsif remaining.to_s == "0" && reset_at.present?
          reset_at.to_i - Time.now.to_i
        end
      return if seconds.nil?

      seconds = seconds.clamp(1, MAX_SECONDS)
      redis.setex(key(token), seconds, "1")
      Rails.logger.warn("GitHub API rate limited; backing off for #{seconds}s")
      seconds
    end

    def note_response_headers(headers, token: nil)
      headers = headers.to_h.transform_keys { |k| k.to_s.downcase }
      note_rate_limit(
        token:,
        retry_after: headers["retry-after"],
        remaining: headers["x-ratelimit-remaining"],
        reset_at: headers["x-ratelimit-reset"],
      )
    end

    def key(token)
      identity = token.present? ? Digest::SHA1.hexdigest(token) : "unauthenticated"
      "#{KEY_PREFIX}#{identity}"
    end

    private

    def redis
      Discourse.redis.without_namespace
    end
  end
end
