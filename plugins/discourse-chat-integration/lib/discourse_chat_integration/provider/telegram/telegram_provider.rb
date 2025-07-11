# frozen_string_literal: true

module DiscourseChatIntegration
  module Provider
    module TelegramProvider
      PROVIDER_NAME = "telegram".freeze
      PROVIDER_ENABLED_SETTING = :chat_integration_telegram_enabled
      CHANNEL_IDENTIFIER_KEY = "name".freeze
      CHANNEL_PARAMETERS = [
        { key: "name", regex: '^\S+' },
        { key: "chat_id", regex: '^(-?[0-9]+|@\S+)$', unique: true },
      ]

      def self.setup_webhook
        newSecret = SecureRandom.hex
        SiteSetting.chat_integration_telegram_secret = newSecret

        message = { url: Discourse.base_url + "/chat-integration/telegram/command/" + newSecret }

        response = self.do_api_request("setWebhook", message)

        if response["ok"] != true
          # If setting up webhook failed, disable provider
          SiteSetting.chat_integration_telegram_enabled = false
          Rails.logger.error(
            "Failed to setup telegram webhook. Message data= " + message.to_json + " response=" +
              response.to_json,
          )
        end
      end

      def self.sendMessage(message)
        self.do_api_request("sendMessage", message)
      end

      def self.do_api_request(methodName, message)
        http = FinalDestination::HTTP.new("api.telegram.org", 443)
        http.use_ssl = true

        access_token = SiteSetting.chat_integration_telegram_access_token

        uri = URI("https://api.telegram.org/bot#{access_token}/#{methodName}")

        req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        req.body = message.to_json
        response = http.request(req)

        responseData = JSON.parse(response.body)

        responseData
      end

      def self.message_text(post)
        display_name = ::DiscourseChatIntegration::Helper.formatted_display_name(post.user)

        topic = post.topic

        category = ""
        if topic.category
          category =
            (
              if (topic.category.parent_category)
                "[#{topic.category.parent_category.name}/#{topic.category.name}]"
              else
                "[#{topic.category.name}]"
              end
            )
        end

        tags = ""
        tags = topic.tags.map(&:name).join(", ") if topic.tags.present?

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
          raise ::DiscourseChatIntegration::ProviderError.new info: {
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

require_relative "telegram_command_controller.rb"
