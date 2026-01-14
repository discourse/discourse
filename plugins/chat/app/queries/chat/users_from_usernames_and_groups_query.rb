# frozen_string_literal: true

module Chat
  class UsersFromUsernamesAndGroupsQuery
    def self.call(usernames:, groups:, excluded_user_ids: [], dm_channel: false)
      opts = { chat_enabled: true }
      opts[:allow_private_messages] = true if dm_channel

      User
        .joins(:user_option)
        .left_outer_joins(:groups)
        .where(user_options: opts)
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
