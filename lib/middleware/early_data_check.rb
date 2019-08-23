# frozen_string_literal: true

module Middleware
  class EarlyDataCheck
    def initialize(app, settings = nil)
      @app = app
    end

    # When a new connection happens, and it uses TLS 1.3 0-RTT
    # the reverse proxy will set the header `Early-Data` to 1.
    # Due to 0-RTT susceptibility to Replay Attacks only GET
    # requests for anonymous users are allowed.
    # Reference: https://tools.ietf.org/html/rfc8446#appendix-E.5
    def call(env)
      if env['HTTP_EARLY_DATA'].to_s == '1' &&
         (env['REQUEST_METHOD'] != 'GET' || CurrentUser.has_auth_cookie?(env))
        [
          425,
          { 'Content-Type' => 'text/html', 'Content-Length' => '9' },
          ['Too Early']
        ]
      else
        @app.call(env)
      end
    end
  end
end
