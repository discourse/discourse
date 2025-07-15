# frozen_string_literal: true

module DiscourseGamification
  class RecalculateScoresRateLimiter
    def self.perform!
      new.perform!
    end

    def self.remaining
      new.remaining
    end

    def initialize
      @rate_limiter = RateLimiter.new(nil, "recalculate_scores_remaining", 5, 24.hours)
    end

    def perform!
      @rate_limiter.performed!
    end

    def remaining
      @rate_limiter.remaining
    end
  end
end
