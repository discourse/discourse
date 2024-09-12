# frozen_string_literal: true

class Chat::DirectMessageChannel::Policy::CanCommunicateAllParties < Service::PolicyBase
  delegate :target_users, :user_comm_screener, to: :context

  def call
    acting_user_can_message_all_target_users? &&
      acting_user_not_preventing_messages_from_any_target_users? &&
      acting_user_not_ignoring_any_target_users? && acting_user_not_muting_any_target_users?
  end

  def reason
    if !acting_user_can_message_all_target_users?
      I18n.t("chat.errors.not_accepting_dms", username: actor_cannot_message_user.username)
    elsif !acting_user_not_preventing_messages_from_any_target_users?
      I18n.t(
        "chat.errors.actor_preventing_target_user_from_dm",
        username: actor_disallowing_pm_user.username,
      )
    elsif !acting_user_not_ignoring_any_target_users?
      I18n.t("chat.errors.actor_ignoring_target_user", username: actor_ignoring_user.username)
    elsif !acting_user_not_muting_any_target_users?
      I18n.t("chat.errors.actor_muting_target_user", username: actor_muting_user.username)
    end
  end

  private

  def acting_user_can_message_all_target_users?
    @acting_user_can_message_all_target_users ||=
      user_comm_screener.preventing_actor_communication.none?
  end

  def acting_user_not_preventing_messages_from_any_target_users?
    @acting_user_not_preventing_messages_from_any_target_users ||=
      !user_comm_screener.actor_disallowing_any_pms?(target_users_without_self.map(&:id))
  end

  def acting_user_not_ignoring_any_target_users?
    @acting_user_not_ignoring_any_target_users ||= actor_ignoring_user.blank?
  end

  def acting_user_not_muting_any_target_users?
    @acting_user_not_muting_any_target_users ||= actor_muting_user.blank?
  end

  def actor_cannot_message_user
    target_users_without_self.find do |user|
      user.id == user_comm_screener.preventing_actor_communication.first
    end
  end

  def actor_disallowing_pm_user
    target_users_without_self.find do |target_user|
      user_comm_screener.actor_disallowing_pms?(target_user.id)
    end
  end

  def actor_ignoring_user
    target_users_without_self.find do |target_user|
      user_comm_screener.actor_ignoring?(target_user.id)
    end
  end

  def actor_muting_user
    target_users_without_self.find do |target_user|
      user_comm_screener.actor_muting?(target_user.id)
    end
  end

  def target_users_without_self
    @target_users_without_self ||= target_users.reject { |user| user.id == guardian.user.id }
  end
end
