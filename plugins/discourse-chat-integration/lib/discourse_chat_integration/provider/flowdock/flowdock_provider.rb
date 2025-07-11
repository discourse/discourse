# frozen_string_literal: true

module DiscourseChatIntegration::Provider::FlowdockProvider
  PROVIDER_NAME = "flowdock".freeze
  PROVIDER_ENABLED_SETTING = :chat_integration_flowdock_enabled
  CHANNEL_IDENTIFIER_KEY = "flow_token".freeze # this is really weird but is the only way to identify a channel in this provider
  CHANNEL_PARAMETERS = [{ key: "flow_token", regex: '^\S+', unique: true, hidden: true }]

  def self.send_message(url, message)
    uri = URI(url)

    http = FinalDestination::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    req.body = message.to_json
    response = http.request(req)

    response
  end

  def self.generate_flowdock_message(post, flow_token)
    display_name = ::DiscourseChatIntegration::Helper.formatted_display_name(post.user)

    message = {
      flow_token: flow_token,
      event: "discussion",
      author: {
        name: display_name,
        avatar: post.user.small_avatar_url,
      },
      title: I18n.t("chat_integration.provider.flowdock.message_title"),
      external_thread_id: post.topic.id,
      body:
        post.excerpt(
          SiteSetting.chat_integration_flowdock_excerpt_length,
          text_entities: true,
          strip_links: false,
          remap_emoji: true,
        ),
      thread: {
        title: post.topic.title,
        external_url: post.full_url,
      },
    }

    message
  end

  def self.trigger_notification(post, channel, rule)
    flow_token = channel.data["flow_token"]
    message = generate_flowdock_message(post, flow_token)
    response = send_message("https://api.flowdock.com/messages", message)

    unless response.kind_of?(Net::HTTPSuccess)
      error_key = nil
      raise ::DiscourseChatIntegration::ProviderError.new info: {
                                                            error_key: error_key,
                                                            message: message,
                                                            response_body: response.body,
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
