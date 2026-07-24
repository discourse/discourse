# frozen_string_literal: true

class Chat::Channel::Policy::MessageModification < Service::PolicyBase
  delegate :message, to: :context

  def call
    guardian.can_modify_channel_message?(message.chat_channel)
  end

  def reason
    I18n.t("chat.errors.channel_modify_message_disallowed.#{message.chat_channel.status}")
  end
end
