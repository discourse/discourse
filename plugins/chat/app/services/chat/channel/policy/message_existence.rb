# frozen_string_literal: true

class Chat::Channel::Policy::MessageExistence < Service::PolicyBase
  delegate :channel, :target_message_id, to: :context

  def call
    return true if target_message_id.blank?
    return false if target_message.blank?
    return true if !target_message.trashed?
    if target_message.trashed? && target_message.user_id == guardian.user.id || guardian.is_staff?
      return true
    end
    context[:target_message_id] = nil
    true
  end

  def reason
  end

  private

  def target_message
    @target_message ||=
      Chat::Message.with_deleted.find_by(id: target_message_id, chat_channel: channel)
  end
end
