# frozen_string_literal: true

class Chat::DirectMessageChannel::NotMutingAnyTargetUsersPolicy < Chat::DirectMessageChannel::NotPreventingMessagesFromAnyTargetUsersPolicy
  def reason
    I18n.t("chat.errors.actor_muting_target_user", username: username)
  end

  private

  def filter(target_user)
    user_comm_screener.actor_muting?(target_user.id)
  end
end
