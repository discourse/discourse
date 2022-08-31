# frozen_string_literal: true

class Auth::TelegramAuthenticator < Auth::ManagedAuthenticator
  def name
    "telegram"
  end

  def enabled?
    SiteSetting.enable_telegram_logins
  end

  def register_middleware(omniauth)
    omniauth.provider :telegram,
           setup: lambda { |env|
             strategy = env["omniauth.strategy"]
              strategy.options[:bot_name] = SiteSetting.telegram_bot_name
              strategy.options[:bot_secret] = SiteSetting.telegram_bot_token
           }
  end
end
