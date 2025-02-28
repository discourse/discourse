# frozen_string_literal: true

module Middleware
  class DefaultHeaders
    def initialize(app, settings = {})
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers[
        "Cross-Origin-Opener-Policy"
      ] = SiteSetting.cross_origin_opener_policy_header if html_response?(headers)
      [status, headers, body]
    end

    private

    def html_response?(headers)
      headers["Content-Type"] && headers["Content-Type"] =~ /html/
    end
  end
end
