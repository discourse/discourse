# frozen_string_literal: true

module Middleware
  class EnforceHostname
    def initialize(app, settings = nil)
      @app = app
    end

    def call(env)
      # enforces hostname to match the hostname of our connection
      # this middleware lives after rails multisite so at this point
      # Discourse.current_hostname MUST be canonical, enforce it so
      # all Rails helpers are guaranteed to use it unconditionally and
      # never generate incorrect links
      env[Rack::Request::HTTP_X_FORWARDED_HOST] = nil

      allowed_hostnames = RailsMultisite::ConnectionManagement.current_db_hostnames
      requested_hostname = env[Rack::HTTP_HOST]

      env[Rack::HTTP_HOST] = allowed_hostnames.find { |h| h == requested_hostname } ||
        Discourse.current_hostname_with_port

      @app.call(env)
    end
  end
end
