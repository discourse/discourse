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
      return false unless UpcomingChanges.enabled?(:blog_enabled)

      Instance.cached.any? do |blog|
        next false if !Configuration.custom_domain?(blog)
        origin = URI(Configuration.origin(blog))
        next http_host == "#{origin.host}:#{origin.port}" if origin.port != origin.default_port
        http_host == origin.host || http_host == "#{origin.host}:#{origin.default_port}"
      end
    end
  end
end
