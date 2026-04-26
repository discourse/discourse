# frozen_string_literal: true

module DiscourseChatIntegration
  module Provider
    module TelegramProvider
      PROVIDER_NAME = "telegram"
      POPULARITY_SCORE = 100
      PROVIDER_ENABLED_SETTING = :chat_integration_telegram_enabled
      CHANNEL_IDENTIFIER_KEY = "name"
      CHANNEL_PARAMETERS = [
        { key: "name", regex: '^\S+' },
        { key: "chat_id", regex: '^(-?[0-9]+|@\S+)$', unique: true },
      ]
      ADDITIONAL_SITE_SETTINGS_REQUIRED = true

      def self.setup(current_user, provider_site_settings = {})
        access_token = provider_site_settings[:chat_integration_telegram_access_token].to_s.strip

        if access_token.blank?
          raise DiscourseChatIntegration::ProviderError.new(
                  info: {
                    error_key: "chat_integration.provider.telegram.errors.access_token_required",
                  },
                )
        end

        new_secret = SecureRandom.hex
        setup_webhook(access_token, new_secret)

        setting_update_result =
          SiteSetting::Update.call(
            params: {
              settings: [
                { setting_name: :chat_integration_telegram_access_token, value: access_token },
                { setting_name: :chat_integration_telegram_secret, value: new_secret },
                { setting_name: PROVIDER_ENABLED_SETTING, value: true },
              ],
            },
            guardian: current_user.guardian,
            options: {
              allow_changing_hidden: [:chat_integration_telegram_secret],
            },
          )

        if !setting_update_result.success?
          self.do_api_request("deleteWebhook", {})
          raise DiscourseChatIntegration::ProviderError.new(
                  info: {
                    error_key: "chat_integration.errors.setting_update_failed",
                    response_body: setting_update_result.errors,
                  },
                )
        end
      end

      def self.setup_webhook(access_token, new_secret)
        webhook_message = {
          url: "#{Discourse.base_url}/chat-integration/telegram/command/#{new_secret}",
        }

        response =
          begin
            self.do_api_request("setWebhook", webhook_message, access_token: access_token)
          rescue JSON::ParserError => err
            Rails.logger.error("Failed to parse telegram setWebhook response: #{err.message}")
            { "ok" => false, "description" => err.message }
          end

        if response["ok"] != true
          Rails.logger.error("Failed to setup telegram webhook. response=#{response.to_json}")
          raise DiscourseChatIntegration::ProviderError.new(
                  info: {
                    error_key: "chat_integration.provider.telegram.errors.webhook_setup_failed",
                    response_body: response,
                  },
                )
        end
      end

      def self.sendMessage(message)
        self.do_api_request("sendMessage", message)
      end

      def self.do_api_request(method_name, message, access_token: nil)
        http = FinalDestination::HTTP.new("api.telegram.org", 443)
        http.use_ssl = true

        token = access_token.presence || SiteSetting.chat_integration_telegram_access_token

        uri = URI("https://api.telegram.org/bot#{token}/#{method_name}")

        req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        req.body = message.to_json
        response = http.request(req)

        JSON.parse(response.body)
      end

      def self.message_text(post)
        display_name = DiscourseChatIntegration::Helper.formatted_display_name(post.user)

        topic = post.topic

        I18n.t(
          "chat_integration.provider.telegram.message",
          user: display_name,
          post_url: post.full_url,
          title: CGI.escapeHTML(topic.title),
          post_excerpt:
            post.excerpt(
              SiteSetting.chat_integration_telegram_excerpt_length,
              text_entities: true,
              strip_links: true,
              remap_emoji: true,
            ),
        )
      end

      def self.trigger_notification(post, channel, rule)
        chat_id = channel.data["chat_id"]

        message = {
          chat_id: chat_id,
          text: message_text(post),
          parse_mode: "html",
          disable_web_page_preview: true,
        }

        response = sendMessage(message)

        if response["ok"] != true
          error_key = nil
          if response["description"].include? "chat not found"
            error_key = "chat_integration.provider.telegram.errors.channel_not_found"
          elsif response["description"].include? "Forbidden"
            error_key = "chat_integration.provider.telegram.errors.forbidden"
          end
          raise DiscourseChatIntegration::ProviderError.new info: {
                                                              error_key: error_key,
                                                              message: message,
                                                              response_body: response,
                                                            }
        end
      end

      def self.get_channel_by_name(name)
        DiscourseChatIntegration::Channel
          .with_provider(PROVIDER_NAME)
          .with_data_value(CHANNEL_IDENTIFIER_KEY, name)
          .first
      end
    end
  end
end

require_relative "telegram_command_controller"
