# frozen_string_literal: true

class Auth::DiscordAuthenticator < Auth::ManagedAuthenticator
  class DiscordStrategy < OmniAuth::Strategies::OAuth2
    option :name, 'discord'
    option :scope, 'identify email guilds'

    option :client_options,
            site: 'https://discordapp.com/api',
            authorize_url: 'oauth2/authorize',
            token_url: 'oauth2/token'

    option :authorize_options, %i[scope permissions]

    uid { raw_info['id'] }

    info do
      {
        name: raw_info['username'],
        email: raw_info['verified'] ? raw_info['email'] : nil,
        image: "https://cdn.discordapp.com/avatars/#{raw_info['id']}/#{raw_info['avatar']}"
      }
    end

    extra do
      {
        'raw_info' => raw_info
      }
    end

    def raw_info
      @raw_info ||= access_token.get('users/@me').parsed.
        merge(guilds: access_token.get('users/@me/guilds').parsed)
    end

    def callback_url
      full_host + script_name + callback_path
    end
  end

  def name
    'discord'
  end

  def enabled?
    SiteSetting.enable_discord_logins?
  end

  def register_middleware(omniauth)
    omniauth.provider DiscordStrategy,
                      setup: lambda { |env|
                        strategy = env["omniauth.strategy"]
                        strategy.options[:client_id] = SiteSetting.discord_client_id
                        strategy.options[:client_secret] = SiteSetting.discord_secret
                      }
    end

  def after_authenticate(auth_token, existing_account: nil)
    allowed_guild_ids = SiteSetting.discord_trusted_guilds.split("|")

    if allowed_guild_ids.length > 0
      user_guild_ids = auth_token.extra[:raw_info][:guilds].map { |g| g['id'] }
      if (user_guild_ids & allowed_guild_ids).empty? # User is not in any allowed guilds
        return Auth::Result.new.tap do |auth_result|
          auth_result.failed = true
          auth_result.failed_reason = I18n.t("discord.not_in_allowed_guild")
        end
      end
    end

    super
  end
end
