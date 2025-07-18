# frozen_string_literal: true

module DiscourseChatIntegration
  module Provider
    module DiscordProvider
      PROVIDER_NAME = "discord".freeze
      PROVIDER_ENABLED_SETTING = :chat_integration_discord_enabled
      CHANNEL_IDENTIFIER_KEY = "name".freeze
      CHANNEL_PARAMETERS = [
        { key: "name", regex: '^\S+' },
        {
          key: "webhook_url",
          regex: '^https:\/\/discord\.com\/api\/webhooks\/',
          unique: true,
          hidden: true,
        },
      ].freeze

      def self.send_message(url, message)
        http = FinalDestination::HTTP.new("discord.com", 443)
        http.use_ssl = true

        uri = URI(url)

        req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        req.body = message.to_json
        response = http.request(req)

        response
      end

      def self.ensure_protocol(url)
        return url if !url.start_with?("//")
        "http:#{url}"
      end

      def self.generate_discord_message(post)
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

        message = {
          content: SiteSetting.chat_integration_discord_message_content,
          embeds: [
            {
              title:
                "#{topic.title} #{(category == "[uncategorized]") ? "" : category} #{topic.tags.present? ? topic.tags.map(&:name).join(", ") : ""}",
              color: topic.category ? topic.category.color.to_i(16) : nil,
              description:
                post.excerpt(
                  SiteSetting.chat_integration_discord_excerpt_length,
                  text_entities: true,
                  strip_links: true,
                  remap_emoji: true,
                ),
              url: post.full_url,
              author: {
                name: display_name,
                url: Discourse.base_url + "/u/" + post.user.username,
                icon_url: ensure_protocol(post.user.small_avatar_url),
              },
            },
          ],
        }

        message
      end

      def self.trigger_notification(post, channel, rule)
        # Splitting the URL in order to support custom query parameters (e.g. thread_id=1234)
        splitted_url = channel.data["webhook_url"].split("?")
        # Adding ?wait=true means that we actually get a success/failure response, rather than returning asynchronously
        webhook_url = "#{splitted_url[0]}?wait=true"

        webhook_url += "&" + splitted_url[1] if splitted_url.length > 1
        message = generate_discord_message(post)
        response = send_message(webhook_url, message)

        # If the message fails to send, it might be because it's a forum channel.
        if !response.kind_of?(Net::HTTPSuccess)
          error = JSON.parse(response.body)
          # Error code 220001 occurs when trying to post to a forum channel without a thread_name.
          if error["code"] == 220_001
            message[:thread_name] = message[:embeds][0][:title]
            response = send_message(webhook_url, message)
          end
        end

        if !response.kind_of?(Net::HTTPSuccess)
          raise ::DiscourseChatIntegration::ProviderError.new(
                  info: {
                    error_key: nil,
                    message: message,
                    response_body: response.body,
                  },
                )
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
