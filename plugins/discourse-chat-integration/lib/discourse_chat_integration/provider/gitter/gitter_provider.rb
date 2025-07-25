# frozen_string_literal: true

module DiscourseChatIntegration
  module Provider
    module GitterProvider
      PROVIDER_NAME = "gitter".freeze
      PROVIDER_ENABLED_SETTING = :chat_integration_gitter_enabled
      CHANNEL_IDENTIFIER_KEY = "name".freeze
      CHANNEL_PARAMETERS = [
        { key: "name", regex: '^\S+$', unique: true },
        {
          key: "webhook_url",
          regex: '^https://webhooks\.gitter\.im/e/\S+$',
          unique: true,
          hidden: true,
        },
      ]

      def self.trigger_notification(post, channel, rule)
        message = gitter_message(post)
        response = Net::HTTP.post_form(URI(channel.data["webhook_url"]), message: message)
        unless response.kind_of? Net::HTTPSuccess
          error_key = nil
          raise ::DiscourseChatIntegration::ProviderError.new info: {
                                                                error_key: error_key,
                                                                message: message,
                                                                response_body: response.body,
                                                              }
        end
      end

      def self.gitter_message(post)
        display_name = post.user.username
        topic = post.topic
        parent_category = topic.category.try :parent_category
        category_name =
          (
            if parent_category
              "[#{parent_category.name}/#{topic.category.name}]"
            else
              "[#{topic.category.name}]"
            end
          )

        "[__#{display_name}__ - #{topic.title} - #{category_name}](#{post.full_url})"
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
