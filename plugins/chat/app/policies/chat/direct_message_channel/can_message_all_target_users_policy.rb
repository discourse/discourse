# frozen_string_literal: true

class Chat::DirectMessageChannel::CanMessageAllTargetUsersPolicy < Chat::DirectMessageChannel::NotPreventingMessagesFromAnyTargetUsersPolicy
  def call
    return true if user_comm_screener.preventing_actor_communication.none?
    super
  end

  def reason
    I18n.t("chat.errors.not_accepting_dms", username: username)
  end

  private

  def filter(user)
    user.id == user_comm_screener.preventing_actor_communication.first
  end
end
