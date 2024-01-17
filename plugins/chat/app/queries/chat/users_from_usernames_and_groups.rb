# frozen_string_literal: true

module Chat
  class UsersFromUsernamesAndGroups
    def self.call(usernames:, groups:)
      User
        .joins(:user_option)
        .left_outer_joins(:groups)
        .where(user_options: { chat_enabled: true })
        .where(
          "username IN (?) OR (groups.name IN (?) AND group_users.user_id IS NOT NULL)",
          usernames,
          groups,
        )
        .distinct
    end
  end
end
