# frozen_string_literal: true

class Discourse::Cors
  ORIGINS_ENV = "Discourse_Cors_Origins"

  def initialize(app, options = nil)
    @app = app
    if GlobalSetting.enable_cors && GlobalSetting.cors_origin.present?
      @global_origins = GlobalSetting.cors_origin.split(',').map(&:strip)
    end
  end

  def call(env)

    cors_origins = @global_origins || []
    cors_origins += SiteSetting.cors_origins.split('|') if SiteSetting.cors_origins.present?
    cors_origins = cors_origins.presence

    if env['REQUEST_METHOD'] == ('OPTIONS') && env['HTTP_ACCESS_CONTROL_REQUEST_METHOD']
      return [200, Discourse::Cors.apply_headers(cors_origins, env, {}), []]
    end

    env[Discourse::Cors::ORIGINS_ENV] = cors_origins if cors_origins

    status, headers, body = @app.call(env)
    headers ||= {}

    Discourse::Cors.apply_headers(cors_origins, env, headers) if cors_origins

    [status, headers, body]
  end

  def self.apply_headers(cors_origins, env, headers)
    origin = nil

    if cors_origins
      if origin = env['HTTP_ORIGIN']
        origin = nil unless cors_origins.include?(origin)
      end

      headers['Access-Control-Allow-Origin'] = origin || cors_origins[0]
      headers['Access-Control-Allow-Headers'] = 'Content-Type, Cache-Control, X-Requested-With, X-CSRF-Token, Discourse-Visible, User-Api-Key, User-Api-Client-Id'
      headers['Access-Control-Allow-Credentials'] = 'true'
      headers['Access-Control-Allow-Methods'] = 'POST, PUT, GET, OPTIONS, DELETE'
    end

    headers
  end
end

if GlobalSetting.enable_cors
  Rails.configuration.middleware.insert_before ActionDispatch::Flash, Discourse::Cors
end
