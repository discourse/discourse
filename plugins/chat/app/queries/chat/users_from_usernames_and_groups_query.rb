# frozen_string_literal: true

module Chat
  class UsersFromUsernamesAndGroupsQuery
    def self.call(usernames:, groups:, excluded_user_ids: [])
      User
        .joins(:user_option)
        .left_outer_joins(:groups)
        .where(user_options: { chat_enabled: true })
        .where(
          "username IN (?) OR (groups.name IN (?) AND group_users.user_id IS NOT NULL)",
          usernames&.map(&:to_s),
          groups&.map(&:to_s),
        )
        .where.not(id: excluded_user_ids)
        .distinct
    end
  end
end
