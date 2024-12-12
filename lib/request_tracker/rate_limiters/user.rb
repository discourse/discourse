# frozen_string_literal: true

module RequestTracker
  module RateLimiters
    class User < Base
      def rate_limit_key
        @cookie[:user_id]
      end

      def rate_limit_key_description
        "user"
      end

      def rate_limit_globally?
        false
      end

      def active?
        @cookie && @cookie[:user_id] && @cookie[:trust_level] &&
          @cookie[:trust_level] >= GlobalSetting.skip_per_ip_rate_limit_trust_level
      end
    end
  end
end
