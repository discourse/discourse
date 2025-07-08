# frozen_string_literal: true

class Auth::TwitterAuthenticator < Auth::ManagedAuthenticator
  def name
    "twitter"
  end

  def display_name
    "X / Twitter"
  end

  def provider_url
    "https://x.com"
  end

  def enabled?
    SiteSetting.enable_twitter_logins
  end

  def healthy?
    connection =
      Faraday.new(url: "https://api.twitter.com") do |config|
        config.basic_auth(SiteSetting.twitter_consumer_key, SiteSetting.twitter_consumer_secret)
      end
    connection.post("/oauth2/token").status == 200
  rescue Faraday::Error
    false
  end

  def after_authenticate(auth_token, existing_account: nil)
    # Twitter sends a huge amount of data which we don't need, so ignore it
    auth_token[:extra] = {}
    super
  end

  def register_middleware(omniauth)
    omniauth.provider :twitter,
                      setup:
                        lambda { |env|
                          strategy = env["omniauth.strategy"]
                          strategy.options[:consumer_key] = SiteSetting.twitter_consumer_key
                          strategy.options[:consumer_secret] = SiteSetting.twitter_consumer_secret
                        }
  end

  # twitter doesn't return unverfied email addresses in the API
  # https://developer.twitter.com/en/docs/twitter-api/v1/accounts-and-users/manage-account-settings/api-reference/get-account-verify_credentials
  def primary_email_verified?(auth_token)
    true
  end
end
