if GlobalSetting.enable_cors && GlobalSetting.cors_origin.present?

  class Discourse::Cors
    def initialize(app, options = nil)
      @app = app
      @origins = GlobalSetting.cors_origin.split(',').map(&:strip)
    end

    def call(env)
      status, headers, body = @app.call(env)
      origin = nil

      if origin = env['HTTP_ORIGIN']
        origin = nil unless @origins.include? origin
      end

      headers['Access-Control-Allow-Origin'] = origin || @origins[0]
      [status,headers,body]
    end
  end

  Rails.configuration.middleware.insert 0, Discourse::Cors
end
