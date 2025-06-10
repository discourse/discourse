# frozen_string_literal: true

require "middleware/omniauth_bypass_middleware"
Rails.application.config.middleware.use Middleware::OmniauthBypassMiddleware

OmniAuth.config.logger = Rails.logger
OmniAuth.config.silence_get_warning = true

# uncomment this line to force the redirect to /auth/failure in development mode
# (by default, omniauth raises an exception in development mode)
# OmniAuth.config.failure_raise_out_environments = []

OmniAuth.config.request_validation_phase = nil # We handle CSRF checks in before_request_phase
OmniAuth.config.before_request_phase do |env|
  request = ActionDispatch::Request.new(env)

  # Check for CSRF token in POST requests
  CSRFTokenVerifier.new.call(env) if request.request_method.downcase.to_sym != :get

  # If the user is trying to reconnect to an existing account, store in session
  request.session[:auth_reconnect] = !!request.params["reconnect"]

  # If the client provided an origin, store in session to redirect back
  request.session[:destination_url] = request.params["origin"]
end

OmniAuth.config.on_failure do |env|
  exception = env["omniauth.error"]

  # OmniAuth 2 doesn't give us any way to know for sure whether a failure was due to an
  # explicit fail! call, or a rescued exception. But, this check is a pretty good guess:
  is_rescued_error = exception&.message&.to_sym == env["omniauth.error.type"]

  next OmniAuth::FailureEndpoint.call(env) if !is_rescued_error # let the default behavior handle it

  case exception
  when OAuth::Unauthorized
    # OAuth1 (i.e. Twitter) makes a web request during the setup phase
    # If it fails, Omniauth does not handle the error. Handle it here
    env["omniauth.error.type"] = "request_error"
  when JWT::InvalidIatError
    # Happens for openid-connect (including google) providers, when the server clock is wrong
    env["omniauth.error.type"] = "invalid_iat"
  when CSRFTokenVerifier::InvalidCSRFToken
    # Happens when CSRF token is missing from request
    env["omniauth.error.type"] = "csrf_detected"
  else
    # default omniauth behavior is to redirect to /auth/failure with error.message in the URL
    # We don't want to leak that kind of unhandled exception info, so re-raise it
    raise exception
  end

  OmniAuth::FailureEndpoint.call(env)
end

OmniAuth.config.full_host = Proc.new { Discourse.base_url_no_prefix }
