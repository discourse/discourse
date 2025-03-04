# frozen_string_literal: true

module Middleware
  class DefaultHeaders
    HTML_ONLY_HEADERS = Set.new(%w[X-Frame-Options X-XSS-Protection])

    def initialize(app, settings = {})
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      is_html_response = html_response?(headers)

      if default_headers = Rails.application.config.action_dispatch.default_headers
        default_headers.each do |header_name, value|
          next if !is_html_response && HTML_ONLY_HEADERS.include?(header_name)

          headers[header_name] = value if headers[header_name].nil?
        end
      end

      headers[
        "Cross-Origin-Opener-Policy"
      ] = SiteSetting.cross_origin_opener_policy_header if is_html_response &&
        headers["Cross-Origin-Opener-Policy"].nil?

      [status, headers, body]
    end

    private

    def html_response?(headers)
      headers["Content-Type"] && headers["Content-Type"] =~ /html/
    end
  end
end
