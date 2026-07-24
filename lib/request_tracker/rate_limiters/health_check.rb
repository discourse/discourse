# frozen_string_literal: true

module RequestTracker
  module RateLimiters
    # Rate limits health check requests per backend instead of sharing the
    # per-IP budget.
    #
    # Load balancers check every backend they route to, and every backend
    # increments the same Redis-backed per-IP counter, so health check
    # volume scales with backend count while the budget does not. With
    # enough backends, the checks alone exceed the limit and all backends
    # get marked down with 429s. Including the backend hostname in the key
    # gives each backend its own budget, so the per-key rate stays
    # constant at any scale.
    #
    # Health checks from private addresses already skip rate limiting, so
    # most deployments see no change; this matters when checks arrive from
    # publicly-routable addresses (e.g. public IPv6 ranges).
    class HealthCheck < Base
      def rate_limit_key
        "health_check/#{@request.ip}/#{Discourse.os_hostname}"
      end

      def rate_limit_globally?
        true
      end

      def active?
        @request.path == "/srv/status"
      end
    end
  end
end
