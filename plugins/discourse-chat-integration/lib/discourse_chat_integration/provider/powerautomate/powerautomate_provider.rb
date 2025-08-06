# frozen_string_literal: true

module DiscourseChatIntegration::Provider::PowerAutomateProvider
  PROVIDER_NAME = "powerautomate"
  PROVIDER_ENABLED_SETTING = :chat_integration_powerautomate_enabled
  CHANNEL_IDENTIFIER_KEY = "name".freeze
  CHANNEL_PARAMETERS = [
    { key: "name", regex: '^\S+$', unique: true },
    { key: "webhook_url", regex: '^https:\/\/\S+$', unique: true, hidden: true },
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
      if response.body.include?("Invalid webhook URL")
        error_key = "chat_integration.provider.powerautomate.errors.invalid_webhook"
      else
        error_key = nil
      end
      raise ::DiscourseChatIntegration::ProviderError.new info: {
                                                            error_key: error_key,
                                                            request: req.body,
                                                            response_code: response.code,
                                                            response_body: response.body,
                                                          }
    end
  end

  def self.get_message(post)
    display_name = "@#{post.user.username}"
    full_name =
      if SiteSetting.enable_names && post.user.name.present?
        post.user.name
      else
        ""
      end

    topic = post.topic

    category = ""
    if topic.category&.uncategorized?
      category = "[#{I18n.t("uncategorized_category_name")}]"
    elsif topic.category
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
      type: "message",
      attachments: [
        {
          contentType: "application/vnd.microsoft.card.adaptive",
          contentUrl: nil,
          content: {
            type: "AdaptiveCard",
            body: [
              {
                type: "TextBlock",
                size: "Large",
                weight: "Bolder",
                text:
                  "[#{topic.title} #{category} #{topic.tags.present? ? topic.tags.map(&:name).join(", ") : ""}](#{post.full_url})",
                wrap: true,
                spacing: "None",
              },
              {
                type: "ColumnSet",
                columns: [
                  {
                    type: "Column",
                    items: [
                      {
                        type: "Image",
                        style: "Person",
                        url: post.user.small_avatar_url,
                        altText: full_name,
                        size: " Small",
                      },
                    ],
                    width: "auto",
                  },
                  {
                    type: "Column",
                    items: [
                      { type: "TextBlock", weight: "Bolder", text: full_name, wrap: true },
                      {
                        type: "TextBlock",
                        spacing: "None",
                        text: display_name,
                        isSubtle: true,
                        wrap: true,
                      },
                    ],
                    width: "stretch",
                  },
                ],
              },
              {
                type: "TextBlock",
                text:
                  post.excerpt(
                    SiteSetting.chat_integration_powerautomate_excerpt_length,
                    text_entities: true,
                    strip_links: true,
                    remap_emoji: true,
                  ),
                wrap: true,
              },
            ],
            "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            version: "1.2",
          },
        },
      ],
    }

    message
  end

  def self.get_channel_by_name(name)
    DiscourseChatIntegration::Channel
      .with_provider(PROVIDER_NAME)
      .with_data_value(CHANNEL_IDENTIFIER_KEY, name)
      .first
  end
end
