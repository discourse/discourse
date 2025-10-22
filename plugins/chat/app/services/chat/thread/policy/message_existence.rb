# frozen_string_literal: true

class Chat::Thread::Policy::MessageExistence < Service::PolicyBase
  delegate :target_message_id, :thread, to: :context

  def call
    return true if target_message_id.blank?
    return false if target_message.blank?
    return true if !target_message.trashed?
    target_message.user_id == guardian.user.id || guardian.is_staff?
  end

  def reason
  end

  private

  def target_message
    @target_message ||= Chat::Message.with_deleted.find_by(id: target_message_id, thread:)
  end
end
