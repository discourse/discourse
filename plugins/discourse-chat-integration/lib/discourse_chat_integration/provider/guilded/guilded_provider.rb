# frozen_string_literal: true

module DiscourseChatIntegration
  module Provider
    module GuildedProvider
      PROVIDER_NAME = "guilded".freeze
      PROVIDER_ENABLED_SETTING = :chat_integration_guilded_enabled
      CHANNEL_IDENTIFIER_KEY = "name".freeze
      CHANNEL_PARAMETERS = [
        { key: "name", regex: '^\S+' },
        {
          key: "webhook_url",
          regex: '^https:\/\/media\.guilded\.gg\/webhooks\/',
          unique: true,
          hidden: true,
        },
      ].freeze

      def self.trigger_notification(post, channel, rule)
        webhook_url = channel.data["webhook_url"]
        message = generate_guilded_message(post)
        response = send_message(webhook_url, message)

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

      def self.generate_guilded_message(post)
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
        display_name = ::DiscourseChatIntegration::Helper.formatted_display_name(post.user)

        icon_url =
          if (url = (SiteSetting.try(:site_logo_small_url) || SiteSetting.logo_small_url)).present?
            "#{Discourse.base_url}#{url}"
          end

        message = {
          embeds: [
            {
              title:
                "#{topic.title} #{(category == "[uncategorized]") ? "" : category} #{topic.tags.present? ? topic.tags.map(&:name).join(", ") : ""}",
              url: post.full_url,
              description:
                post.excerpt(
                  SiteSetting.chat_integration_guilded_excerpt_length,
                  text_entities: true,
                  strip_links: true,
                  remap_emoji: true,
                ),
              footer: {
                icon_url: ensure_protocol(post.user.small_avatar_url),
                text: "#{display_name} | #{post.created_at}",
              },
            },
          ],
        }

        message
      end

      def self.send_message(url, message)
        uri = URI(url)
        http = FinalDestination::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")

        req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        req.body = message.to_json
        response = http.request(req)

        response
      end

      def self.ensure_protocol(url)
        return url if !url.start_with?("//")
        "http:#{url}"
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
