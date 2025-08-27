# frozen_string_literal: true

# name: discourse-apple-auth
# about: Allows users to login using Apple authentication.
# meta_topic_id: 171485
# version: 1.0
# authors: Robert Barrow, David Taylor
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-apple-auth

require_relative "lib/omniauth_apple"

register_svg_icon "fab-apple"

enabled_site_setting :sign_in_with_apple_enabled

class AppleAuthenticator < ::Auth::ManagedAuthenticator
  def name
    "apple"
  end

  def enabled?
    SiteSetting.sign_in_with_apple_enabled?
  end

  def fetch_jwks(options)
    Discourse
      .cache
      .fetch("sign-in-with-apple-jwks", expires_in: 1.day) do
        connection = Faraday.new { |c| c.use Faraday::Response::RaiseError }
        JSON.parse(
          connection.get("https://appleid.apple.com/auth/keys").body,
          symbolize_names: true,
        )
      end
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error("Unable to fetch sign-in-with-apple-jwks #{e.class} #{e.message}")
    nil
  end

  def register_middleware(omniauth)
    omniauth.provider :apple,
                      setup:
                        lambda { |env|
                          strategy = env["omniauth.strategy"]
                          strategy.options[:client_id] = SiteSetting.apple_client_id
                          strategy.options[:team_id] = SiteSetting.apple_team_id
                          strategy.options[:key_id] = SiteSetting.apple_key_id
                          strategy.options[:pem] = SiteSetting.apple_pem
                          strategy.options[:jwk_fetcher] = ->(options) { fetch_jwks(options) }
                        }
  end

  # apple requires email verification to create an account so we can assume
  # email is verified
  def primary_email_verified?(auth_token)
    true
  end
end

auth_provider icon: "fab-apple", authenticator: AppleAuthenticator.new
