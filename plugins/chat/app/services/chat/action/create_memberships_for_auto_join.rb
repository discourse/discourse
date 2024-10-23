# frozen_string_literal: true

module Chat
  module Action
    class CreateMembershipsForAutoJoin < Service::ActionBase
      option :channel
      option :params

      def call
        ::DB.query_single(<<~SQL, query_args)
          INSERT INTO user_chat_channel_memberships (user_id, chat_channel_id, following, created_at, updated_at, join_mode)
          SELECT DISTINCT(users.id), :chat_channel_id, TRUE, NOW(), NOW(), :mode
          FROM users
          INNER JOIN user_options uo ON uo.user_id = users.id
          LEFT OUTER JOIN user_chat_channel_memberships uccm ON
            uccm.chat_channel_id = :chat_channel_id AND uccm.user_id = users.id

          LEFT OUTER JOIN group_users gu ON gu.user_id = users.id
          LEFT OUTER JOIN category_groups cg ON cg.group_id = gu.group_id AND
          cg.permission_type <= :permission_type

          WHERE (users.id >= :start AND users.id <= :end) AND
            users.staged IS FALSE AND
            users.active AND
            NOT EXISTS(SELECT 1 FROM anonymous_users a WHERE a.user_id = users.id) AND
            (suspended_till IS NULL OR suspended_till <= :suspended_until) AND
            (last_seen_at IS NULL OR last_seen_at > :last_seen_at) AND
            uo.chat_enabled AND

            (NOT EXISTS(SELECT 1 FROM category_groups WHERE category_id = :channel_category)
              OR EXISTS (SELECT 1 FROM category_groups WHERE category_id = :channel_category AND group_id = :everyone AND permission_type <= :permission_type)
              OR cg.category_id = :channel_category)

          ON CONFLICT DO NOTHING

          RETURNING user_chat_channel_memberships.user_id
        SQL
      end

      private

      def query_args
        {
          chat_channel_id: channel.id,
          start: params.start_user_id,
          end: params.end_user_id,
          suspended_until: Time.zone.now,
          last_seen_at: 3.months.ago,
          channel_category: channel.category.id,
          permission_type: CategoryGroup.permission_types[:create_post],
          everyone: Group::AUTO_GROUPS[:everyone],
          mode: ::Chat::UserChatChannelMembership.join_modes[:automatic],
        }
      end
    end
  end
end
