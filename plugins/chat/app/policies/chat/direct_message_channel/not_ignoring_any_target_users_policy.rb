# frozen_string_literal: true

class Chat::DirectMessageChannel::NotIgnoringAnyTargetUsersPolicy < Chat::DirectMessageChannel::NotPreventingMessagesFromAnyTargetUsersPolicy
  def reason
    I18n.t("chat.errors.actor_ignoring_target_user", username: username)
  end

  private

  def filter(target_user)
    user_comm_screener.actor_ignoring?(target_user.id)
  end
end
