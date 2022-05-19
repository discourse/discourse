# frozen_string_literal: true

# Implementing cookies rotator for Rails 7+ as a middleware because this will
# work in single site mode AND in multisite mode without leaking anything in
# `Rails.application.config.action_dispatch.cookies_rotations`.
module Middleware
  class CookiesRotator
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      env[
        ActionDispatch::Cookies::COOKIES_ROTATIONS
      ] = ActiveSupport::Messages::RotationConfiguration.new.tap do |cookies|
        key_generator =
          ActiveSupport::KeyGenerator.new(
            request.secret_key_base,
            iterations: 1000,
            hash_digest_class: OpenSSL::Digest::SHA1,
          )
        key_len = ActiveSupport::MessageEncryptor.key_len

        cookies.rotate(
          :encrypted,
          key_generator.generate_key(request.authenticated_encrypted_cookie_salt, key_len),
        )
        cookies.rotate(:signed, key_generator.generate_key(request.signed_cookie_salt))
      end
      @app.call(env)
    end
  end
end
