# frozen_string_literal: true

class Discourse::Cors
  ORIGINS_ENV = "Discourse_Cors_Origins"

  def initialize(app, options = nil)
    @app = app
    if GlobalSetting.enable_cors && GlobalSetting.cors_origin.present?
      @global_origins = GlobalSetting.cors_origin.split(",").map { |x| x.strip.chomp("/") }
    end
  end

  def call(env)
    cors_origins = @global_origins || []
    cors_origins += SiteSetting.cors_origins.split("|") if SiteSetting.cors_origins.present?
    cors_origins = cors_origins.presence

    if env["REQUEST_METHOD"] == ("OPTIONS") && env["HTTP_ACCESS_CONTROL_REQUEST_METHOD"]
      return 200, Discourse::Cors.apply_headers(cors_origins, env, {}), []
    end

    env[Discourse::Cors::ORIGINS_ENV] = cors_origins if cors_origins

    status, headers, body = @app.call(env)
    headers ||= {}

    Discourse::Cors.apply_headers(cors_origins, env, headers)

    [status, headers, body]
  end

  def self.apply_headers(cors_origins, env, headers)
    request_method = env["REQUEST_METHOD"]

    if env["REQUEST_PATH"] =~ %r{/(javascripts|assets)/} &&
         Discourse.is_cdn_request?(env, request_method)
      Discourse.apply_cdn_headers(headers)
    elsif cors_origins
      origin = nil
      if origin = env["HTTP_ORIGIN"]
        origin = nil unless cors_origins.include?(origin)
      end

      headers["Access-Control-Allow-Origin"] = origin || cors_origins[0]
      headers[
        "Access-Control-Allow-Headers"
      ] = "Content-Type, Cache-Control, X-Requested-With, X-CSRF-Token, Discourse-Present, User-Api-Key, User-Api-Client-Id, Authorization"
      headers["Access-Control-Allow-Credentials"] = "true"
      headers["Access-Control-Allow-Methods"] = "POST, PUT, GET, OPTIONS, DELETE"
      headers["Access-Control-Max-Age"] = "7200"
    end

    headers
  end
end

if GlobalSetting.enable_cors || GlobalSetting.cdn_url
  Rails.configuration.middleware.insert_before ActionDispatch::Flash, Discourse::Cors
end
