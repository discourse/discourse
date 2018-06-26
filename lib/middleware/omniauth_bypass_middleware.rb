# frozen_string_literal: true

# omniauth loves spending lots cycles in its magic middleware stack
# this middleware bypasses omniauth middleware and only hits it when needed
class Middleware::OmniauthBypassMiddleware

  def initialize(app, options = {})
    @app = app

    # if you need to test this and are having ssl issues see:
    #  http://stackoverflow.com/questions/6756460/openssl-error-using-omniauth-specified-ssl-path-but-didnt-work
    # OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
    @omniauth = OmniAuth::Builder.new(app) do
      Discourse.authenticators.each do |authenticator|
        authenticator.register_middleware(self)
      end
    end
  end

  def call(env)
    if env["PATH_INFO"].start_with?("/auth")
      @omniauth.call(env)
    else
      @app.call(env)
    end
  end

end
