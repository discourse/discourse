# frozen_string_literal: true

require "openssl"

require "middleware/omniauth_bypass_middleware"
Rails.application.config.middleware.use Middleware::OmniauthBypassMiddleware

OmniAuth.config.logger = Rails.logger
OmniAuth.config.silence_get_warning = true
