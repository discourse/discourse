# frozen_string_literal: true

module Middleware
  class OverloadProtections
    def initialize(app)
      @app = app
    end

    def call(env)
      is_logged_in = Auth::DefaultCurrentUserProvider.find_v1_auth_cookie(env).present?

      if !is_logged_in &&
           env[Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY].to_f >
             GlobalSetting.reject_anonymous_min_queue_seconds
        return [
          503,
          { "Content-Type" => "text/plain" },
          ["Server is currently experiencing high load. Please try again later."]
        ]
      end

      @app.call(env)
    end
  end
end
