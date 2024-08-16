# frozen_string_literal: true

module Jobs
  module Chat
    class AutoJoinUsers < ::Jobs::Scheduled
      every 1.hour

      LAST_SEEN_DAYS = 30

      def execute(_args)
        return if !SiteSetting.chat_enabled

        allowed_group_permissions = [
          CategoryGroup.permission_types[:create_post],
          CategoryGroup.permission_types[:full],
        ]

        join_mode = ::Chat::UserChatChannelMembership.join_modes[:automatic]

        sql = <<~SQL
          WITH users AS (
            SELECT id FROM users u
            JOIN user_options uo ON uo.user_id = u.id
            WHERE id > 0  AND (u.suspended_till IS NULL OR u.suspended_till <= :now)
                          AND (u.last_seen_at IS NULL OR u.last_seen_at > :last_seen_at)
                          AND u.active
                          AND NOT u.staged
                          AND uo.chat_enabled
                          AND NOT EXISTS (SELECT 1 FROM anonymous_users a WHERE a.user_id = u.id)
            ORDER BY last_seen_at desc
            LIMIT :max_users
          )

          INSERT INTO user_chat_channel_memberships (user_id, chat_channel_id, following, created_at, updated_at, join_mode)
          SELECT DISTINCT users.id AS user_id,
                          chat_channels.id AS chat_channel_id,
                          TRUE AS following,
                          :now::timestamp AS created_at,
                          :now::timestamp AS updated_at,
                          :join_mode AS join_mode
          FROM users
          JOIN chat_channels on auto_join_users AND chatable_type = 'Category'
          JOIN categories c on c.id = chat_channels.chatable_id

          LEFT OUTER JOIN user_chat_channel_memberships uccm ON uccm.chat_channel_id = chat_channels.id
                                                              AND uccm.user_id = users.id
          LEFT OUTER JOIN group_users gu ON gu.user_id = users.id
          LEFT OUTER JOIN category_groups cg ON cg.group_id = gu.group_id
                                              AND cg.permission_type in (:allowed_group_permissions)
                                              AND c.id = cg.category_id

          WHERE  (cg.group_id is NOT null OR NOT c.read_restricted) AND uccm.id IS NULL
          ON CONFLICT DO NOTHING
        SQL

        DB.exec(
          sql,
          now: Time.zone.now,
          last_seen_at: LAST_SEEN_DAYS.days.ago,
          allowed_group_permissions: allowed_group_permissions,
          join_mode: join_mode,
          max_users: SiteSetting.max_chat_auto_joined_users,
        )
      end
    end
  end
end
