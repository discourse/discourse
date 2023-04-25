# frozen_string_literal: true

class Chat::DirectMessageChannel::NotPreventingMessagesFromAnyTargetUsersPolicy < PolicyBase
  delegate :user_comm_screener, :target_users, to: :context

  def call
    username.blank?
  end

  def reason
    I18n.t("chat.errors.actor_preventing_target_user_from_dm", username: username)
  end

  private

  def username
    @username ||= target_users.find(&method(:filter))&.username
  end

  def filter(target_user)
    user_comm_screener.actor_disallowing_pms?(target_user.id)
  end
end
