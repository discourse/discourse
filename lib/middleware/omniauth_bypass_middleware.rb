# frozen_string_literal: true

# omniauth loves spending lots cycles in its magic middleware stack
# this middleware bypasses omniauth middleware and only hits it when needed
class Middleware::OmniauthBypassMiddleware
  def initialize(app, options = {})
    @app = app
  end

  def call(env)
    @app.call(env) unless env["PATH_INFO"].start_with?("/auth")

    # When only one provider is enabled, assume it can be completely trusted, and allow GET requests
    only_one_provider =
      !SiteSetting.enable_local_logins && Discourse.enabled_authenticators.length == 1
    OmniAuth.config.allowed_request_methods = only_one_provider ? %i[get post] : [:post]

    omniauth =
      OmniAuth::Builder.new(@app) do
        Discourse.enabled_authenticators.each do |authenticator|
          authenticator.register_middleware(self)
        end
      end

    omniauth.call(env)
  end
end
