require "openssl"
require "openid_redis_store"

require "middleware/omniauth_bypass_middleware"
Rails.application.config.middleware.use Middleware::OmniauthBypassMiddleware

OmniAuth.config.logger = Rails.logger
