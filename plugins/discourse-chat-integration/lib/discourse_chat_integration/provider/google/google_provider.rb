# frozen_string_literal: true

module DiscourseChatIntegration
  module Provider
    module GoogleProvider
      PROVIDER_NAME = "google".freeze
      PROVIDER_ENABLED_SETTING = :chat_integration_google_enabled
      CHANNEL_IDENTIFIER_KEY = "name".freeze
      CHANNEL_PARAMETERS = [
        { key: "name", regex: '^\S+$', unique: true },
        {
          key: "webhook_url",
          regex: '^https:\/\/chat.googleapis.com\/v1\/\S+$',
          unique: true,
          hidden: true,
        },
      ]

      def self.trigger_notification(post, channel, rule)
        message = get_message(post)
        uri = URI(channel.data["webhook_url"])

        http = FinalDestination::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")

        req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        req.body = message.to_json
        response = http.request(req)

        unless response.kind_of? Net::HTTPSuccess
          raise ::DiscourseChatIntegration::ProviderError.new info: {
                                                                request: req.body,
                                                                response_code: response.code,
                                                                response_body: response.body,
                                                              }
        end
      end

      def self.get_message(post)
        {
          cards: [
            {
              sections: [
                {
                  widgets: [
                    {
                      keyValue: {
                        topLabel:
                          I18n.t(
                            "chat_integration.provider.google.new_#{post.is_first_post? ? "topic" : "post"}",
                            site_title: SiteSetting.title,
                          ),
                        content: post.topic.title,
                        contentMultiline: "false",
                        bottomLabel:
                          I18n.t(
                            "chat_integration.provider.google.author",
                            username: post.user.username,
                          ),
                        onClick: {
                          openLink: {
                            url: post.full_url,
                          },
                        },
                      },
                    },
                  ],
                },
                {
                  widgets: [
                    {
                      textParagraph: {
                        text:
                          post.excerpt(
                            SiteSetting.chat_integration_google_excerpt_length,
                            text_entities: true,
                            strip_links: true,
                            remap_emoji: true,
                          ),
                      },
                    },
                  ],
                },
                {
                  widgets: [
                    {
                      buttons: [
                        {
                          textButton: {
                            text:
                              I18n.t(
                                "chat_integration.provider.google.link",
                                site_title: SiteSetting.title,
                              ),
                            onClick: {
                              openLink: {
                                url: post.full_url,
                              },
                            },
                          },
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        }
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
