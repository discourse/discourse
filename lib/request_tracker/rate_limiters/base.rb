# frozen_string_literal: true

module RequestTracker
  module RateLimiters
    class Base
      # :nodoc:
      def initialize(request, cookie)
        @request = request
        @cookie = cookie
      end

      # This method is meant to be implemented in subclasses.
      #
      # @return [String] The key used to identify the rate limiter.
      def rate_limit_key
        raise NotImplementedError
      end

      # :nodoc:
      def error_code_identifier
        self.class.name.underscore.split("/").last
      end

      # This method is meant to be implemented in subclasses.
      #
      # @return [Boolean] Indicates if the rate limiter should be used for the request.
      def active?
        raise NotImplementedError
      end

      # This method is meant to be implemented in subclasses.
      #
      # @return [Boolean] Indicates whether the rate limit applies globally across all sites in the cluster or just for
      #   the current site.
      def rate_limit_globally?
        raise NotImplementedError
      end
    end
  end
end
