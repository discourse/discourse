# frozen_string_literal: true

# omniauth loves spending lots cycles in its magic middleware stack
# this middleware bypasses omniauth middleware and only hits it when needed
class Middleware::OmniauthBypassMiddleware
  module OmniAuthStrategyCompatPatch
    def callback_url
      result = super
      if script_name.present? && result.include?("#{script_name}#{script_name}")
        result = result.gsub("#{script_name}#{script_name}", script_name)
        Discourse.deprecate <<~MESSAGE
          OmniAuth strategy '#{name}' included duplicate script_name in callback url. It's likely the callback_url method is concatenating `script_name` with `callback_path`.
          OmniAuth v2 includes the `script_name` in the `callback_path` automatically, so the manual `script_name` call can be removed.
          This issue has been automatically corrected, but the strategy should be updated to ensure subfolder compatibility with future versions of Discourse.
        MESSAGE
      end
      result
    end
  end

  class PatchedOmniAuthBuilder < OmniAuth::Builder
    def use(strategy, *args, **kwargs, &block)
      if !strategy.ancestors.include?(OmniAuthStrategyCompatPatch)
        strategy.prepend(OmniAuthStrategyCompatPatch)
      end
      super(strategy, *args, **kwargs, &block)
    end
  end

  def initialize(app, options = {})
    @app = app
  end

  def call(env)
    return @app.call(env) unless env["PATH_INFO"].start_with?("/auth")

    # When only one provider is enabled, assume it can be completely trusted, and allow GET requests
    only_one_provider =
      !SiteSetting.enable_local_logins && Discourse.enabled_authenticators.length == 1

    allow_get = only_one_provider || !SiteSetting.auth_require_interaction

    OmniAuth.config.allowed_request_methods = allow_get ? %i[get post] : [:post]

    omniauth =
      PatchedOmniAuthBuilder.new(@app) do
        Discourse.enabled_authenticators.each do |authenticator|
          authenticator.register_middleware(self)
        end
      end

    omniauth.call(env)
  end
end
