# frozen_string_literal: true

class ProblemCheck::ChannelErrors < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.chat_integration_enabled
    return no_problem if !channel_errors?

    problem
  end

  private

  def channel_errors?
    DiscourseChatIntegration::Channel.find_each.any? do |channel|
      channel.error_key.present? &&
        ::DiscourseChatIntegration::Provider.is_enabled(channel.provider)
    end
  end
end
