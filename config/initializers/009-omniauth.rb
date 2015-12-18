require "openssl"
require "openid_redis_store"

# if you need to test this and are having ssl issues see:
#  http://stackoverflow.com/questions/6756460/openssl-error-using-omniauth-specified-ssl-path-but-didnt-work

Rails.application.config.middleware.use OmniAuth::Builder do
  Discourse.authenticators.each do |authenticator|
    authenticator.register_middleware(self)
  end
end
