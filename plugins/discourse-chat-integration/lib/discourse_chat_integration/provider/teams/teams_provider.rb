# frozen_string_literal: true

module DiscourseChatIntegration::Provider::TeamsProvider
  PROVIDER_NAME = "teams"
  PROVIDER_ENABLED_SETTING = :chat_integration_teams_enabled
  CHANNEL_IDENTIFIER_KEY = "name"
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
        error_key = "chat_integration.provider.teams.errors.invalid_channel"
      else
        error_key = nil
      end
      raise DiscourseChatIntegration::ProviderError.new info: {
                                                          error_key: error_key,
                                                          request: req.body,
                                                          response_code: response.code,
                                                          response_body: response.body,
                                                        }
    end
  end

  def self.get_message(post)
    display_name = "@#{post.user.username}"
    if SiteSetting.enable_names && post.user.name.present?
      display_name = "#{post.user.name} (#{display_name})"
    end

    topic = post.topic

    category = nil
    if topic.category&.uncategorized?
      category = "#{I18n.t("uncategorized_category_name")}"
    elsif topic.category
      category =
        (
          if (topic.category.parent_category)
            "#{topic.category.parent_category.name}/#{topic.category.name}"
          else
            topic.category.name
          end
        )
    end
    tags = topic.tags.map(&:name).join(", ") if topic.tags.present?
    category_and_tags_line = [category, tags].compact.join(" | ").presence

    body = [
      {
        type: "RichTextBlock",
        inlines: [
          {
            type: "TextRun",
            text: topic.title,
            size: "Large",
            weight: "Bolder",
            selectAction: {
              type: "Action.OpenUrl",
              url: post.full_url,
            },
          },
        ],
      },
    ]

    if category_and_tags_line
      body.push(
        {
          type: "TextBlock",
          text: category_and_tags_line,
          wrap: true,
          size: "Small",
          isSubtle: true,
          weight: "Lighter",
          spacing: "Small",
        },
      )
    end

    body.push(
      {
        type: "ColumnSet",
        columns: [
          {
            type: "Column",
            items: [
              {
                type: "Image",
                style: "Person",
                url: "http:#{post.user.small_avatar_url}",
                altText: display_name,
                size: "Small",
              },
            ],
            width: "auto",
          },
          {
            type: "Column",
            width: "stretch",
            items: [{ type: "TextBlock", weight: "Bolder", text: display_name, wrap: true }],
            verticalContentAlignment: "Center",
            horizontalAlignment: "Left",
          },
        ],
      },
      {
        type: "TextBlock",
        text:
          post.excerpt(
            SiteSetting.chat_integration_teams_excerpt_length,
            text_entities: true,
            strip_links: true,
            remap_emoji: true,
          ),
        wrap: true,
      },
    )

    {
      type: "AdaptiveCard",
      "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
      version: "1.5",
      body: body,
    }
  end

  def self.get_channel_by_name(name)
    DiscourseChatIntegration::Channel
      .with_provider(PROVIDER_NAME)
      .with_data_value(CHANNEL_IDENTIFIER_KEY, name)
      .first
  end
end
