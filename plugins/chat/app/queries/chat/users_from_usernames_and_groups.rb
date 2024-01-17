# frozen_string_literal: true

module Chat
  class UsersFromUsernamesAndGroups
    def self.call(usernames:, groups:)
      User
        .joins(:user_option)
        .left_outer_joins(:groups)
        .where(user_options: { chat_enabled: true })
        .where(username: usernames)
        .or(
          User
            .joins(:user_option)
            .left_outer_joins(:groups)
            .where(user_options: { chat_enabled: true })
            .where(groups: { name: groups })
            .where.not(group_users: { user_id: nil }),
        )
        .distinct
    end
  end
end
