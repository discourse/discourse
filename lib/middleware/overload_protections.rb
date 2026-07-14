# frozen_string_literal: true

module Middleware
  class OverloadProtections
    def initialize(app)
      @app = app
    end

    def call(env)
      if overloaded?(env) && !authenticated_request?(env)
        return [
          503,
          { "Content-Type" => "text/plain" },
          ["Server is currently experiencing high load. Please try again later."]
        ]
      end

      @app.call(env)
    end

    private

    def overloaded?(env)
      env[Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY].to_f >
        GlobalSetting.reject_anonymous_min_queue_seconds
    end

    def authenticated_request?(env)
      Auth::DefaultCurrentUserProvider.find_v1_auth_cookie(env).present? ||
        authenticated_api_request?(env)
    end

    def authenticated_api_request?(env)
      return false unless api_credentials_present?(env)

      Discourse.current_user_provider.new(env).current_user
      env[Auth::DefaultCurrentUserProvider::API_KEY_ENV].present? ||
        env[Auth::DefaultCurrentUserProvider::USER_API_KEY_ENV].present?
    rescue Discourse::InvalidAccess, RateLimiter::LimitExceeded
      false
    end

    def api_credentials_present?(env)
      env[Auth::DefaultCurrentUserProvider::HEADER_API_KEY].present? ||
        env[Auth::DefaultCurrentUserProvider::USER_API_KEY].present?
    end
  end
end
