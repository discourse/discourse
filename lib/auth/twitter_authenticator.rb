# frozen_string_literal: true

class Auth::TwitterAuthenticator < Auth::ManagedAuthenticator
  def name
    "twitter"
  end

  def enabled?
    SiteSetting.enable_twitter_logins
  end

  def after_authenticate(auth_token, existing_account: nil)
    # Twitter sends a huge amount of data which we don't need, so ignore it
    auth_token[:extra] = {}
    super
  end

  def register_middleware(omniauth)
    omniauth.provider :twitter,
           setup: lambda { |env|
             strategy = env["omniauth.strategy"]
              strategy.options[:consumer_key] = SiteSetting.twitter_consumer_key
              strategy.options[:consumer_secret] = SiteSetting.twitter_consumer_secret
           }
  end
end
