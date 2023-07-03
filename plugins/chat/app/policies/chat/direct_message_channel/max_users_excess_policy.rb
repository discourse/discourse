# frozen_string_literal: true

class Chat::DirectMessageChannel::MaxUsersExcessPolicy < PolicyBase
  delegate :target_users, to: :context

  def call
    guardian.is_staff? ||
      target_users_without_self.size <= SiteSetting.chat_max_direct_message_users
  end

  def reason
    return I18n.t("chat.errors.over_chat_max_direct_message_users_allow_self") if no_dm?
    I18n.t(
      "chat.errors.over_chat_max_direct_message_users",
      count: SiteSetting.chat_max_direct_message_users + 1, # +1 for the acting user
    )
  end

  private

  def no_dm?
    SiteSetting.chat_max_direct_message_users.zero?
  end

  def target_users_without_self
    target_users.reject { |user| user.id == guardian.user.id }
  end
end
