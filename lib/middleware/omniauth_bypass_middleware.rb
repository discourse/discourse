# frozen_string_literal: true

require "csrf_token_verifier"

# omniauth loves spending lots cycles in its magic middleware stack
# this middleware bypasses omniauth middleware and only hits it when needed
class Middleware::OmniauthBypassMiddleware
  class AuthenticatorDisabled < StandardError; end

  def initialize(app, options = {})
    @app = app

    Discourse.plugins.each(&:notify_before_auth)

    # if you need to test this and are having ssl issues see:
    #  http://stackoverflow.com/questions/6756460/openssl-error-using-omniauth-specified-ssl-path-but-didnt-work
    # OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
    @omniauth = OmniAuth::Builder.new(app) do
      Discourse.authenticators.each do |authenticator|
        authenticator.register_middleware(self)
      end
    end

    @omniauth.before_request_phase do |env|
      request = ActionDispatch::Request.new(env)

      # Check for CSRF token in POST requests
      CSRFTokenVerifier.new.call(env) if request.request_method.downcase.to_sym != :get

      # Check whether the authenticator is enabled
      if !Discourse.enabled_authenticators.any? { |a| a.name.to_sym == env['omniauth.strategy'].name.to_sym }
        raise AuthenticatorDisabled
      end

      # If the user is trying to reconnect to an existing account, store in session
      request.session[:auth_reconnect] = !!request.params["reconnect"]
    end
  end

  def call(env)
    if env["PATH_INFO"].start_with?("/auth")
      begin
        # When only one provider is enabled, assume it can be completely trusted, and allow GET requests
        only_one_provider = !SiteSetting.enable_local_logins && Discourse.enabled_authenticators.length == 1
        OmniAuth.config.allowed_request_methods = only_one_provider ? [:get, :post] : [:post]

        @omniauth.call(env)
      rescue AuthenticatorDisabled => e
        #  Authenticator is disabled, pretend it doesn't exist and pass request to app
        @app.call(env)
      rescue OAuth::Unauthorized => e
        # OAuth1 (i.e. Twitter) makes a web request during the setup phase
        # If it fails, Omniauth does not handle the error. Handle it here
        env["omniauth.error.type"] ||= "request_error"
        Rails.logger.error "Authentication failure! request_error: #{e.class}, #{e.message}"
        OmniAuth::FailureEndpoint.call(env)
      rescue JWT::InvalidIatError => e
        # Happens for openid-connect (including google) providers, when the server clock is wrong
        env["omniauth.error.type"] ||= "invalid_iat"
        Rails.logger.error "Authentication failure! invalid_iat: #{e.class}, #{e.message}"
        OmniAuth::FailureEndpoint.call(env)
      rescue CSRFTokenVerifier::InvalidCSRFToken => e
        # Happens when CSRF token is missing from request
        env["omniauth.error.type"] ||= "csrf_detected"
        OmniAuth::FailureEndpoint.call(env)
      end
    else
      @app.call(env)
    end
  end

end
