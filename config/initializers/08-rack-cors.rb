if GlobalSetting.enable_cors
  class Discourse::Cors
    def initialize(app, options = nil)
      @app = app
      if GlobalSetting.enable_cors && GlobalSetting.cors_origin.present?
        @global_origins = GlobalSetting.cors_origin.split(',').map(&:strip)
      end
    end

    def call(env)
      status, headers, body = @app.call(env)
      origin = nil
      cors_origins = @global_origins || []
      cors_origins += SiteSetting.cors_origins.split('|') if SiteSetting.cors_origins

      if cors_origins
        if origin = env['HTTP_ORIGIN']
          origin = nil unless cors_origins.include?(origin)
        end

        headers['Access-Control-Allow-Origin'] = origin || cors_origins[0]
        headers['Access-Control-Allow-Credentials'] = "true"
      end

      [status,headers,body]
    end
  end

  Rails.configuration.middleware.use Discourse::Cors
end
