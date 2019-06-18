# frozen_string_literal: true

class RateLimiter

  # A rate limit has been exceeded.
  class LimitExceeded < StandardError
    attr_reader :type, :available_in

    def initialize(available_in, type = nil)
      @available_in = available_in
      @type = type
    end

    def description
      time_left =
        if @available_in <= 3
          I18n.t("rate_limiter.short_time")
        elsif @available_in < 1.minute.to_i
          I18n.t("rate_limiter.seconds", count: @available_in)
        elsif @available_in < 1.hour.to_i
          I18n.t("rate_limiter.minutes", count: (@available_in / 1.minute.to_i))
        else
          I18n.t("rate_limiter.hours", count: (@available_in / 1.hour.to_i))
        end

      if @type.present?
        type_key = @type.tr("-", "_")
        msg = I18n.t("rate_limiter.by_type.#{type_key}", time_left: time_left, default: "")
        return msg if msg.present?
      end

      I18n.t("rate_limiter.too_many_requests", time_left: time_left)
    end
  end

end
