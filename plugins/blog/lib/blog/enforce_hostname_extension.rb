# frozen_string_literal: true

module ::Blog
  module EnforceHostnameExtension
    def call(env)
      if blog_http_host?(env[Rack::HTTP_HOST])
        env[Rack::Request::HTTP_X_FORWARDED_HOST] = nil
        return @app.call(env)
      end

      super
    end

    private

    def blog_http_host?(http_host)
      return false unless SiteSetting.blog_enabled && Configuration.configured_origin?

      origin = URI(Configuration.origin)
      return http_host == "#{origin.host}:#{origin.port}" if origin.port != origin.default_port

      http_host == origin.host || http_host == "#{origin.host}:#{origin.default_port}"
    rescue URI::InvalidURIError
      false
    end
  end
end
