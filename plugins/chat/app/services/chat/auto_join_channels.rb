# frozen_string_literal: true

module Chat
  class AutoJoinChannels
    include Service::Base

    ALLOWED_GROUP_PERMISSIONS = [
      CategoryGroup.permission_types[:create_post],
      CategoryGroup.permission_types[:full],
    ]

    policy :chat_enabled?

    params do
      attribute :user_id, :integer
      attribute :channel_id, :integer
      attribute :category_id, :integer
    end

    step :create_memberships

    private

    def chat_enabled?
      SiteSetting.chat_enabled
    end

    def create_memberships(params:)
      automatic = ::Chat::UserChatChannelMembership.join_modes[:automatic]
      group_permissions = ALLOWED_GROUP_PERMISSIONS
      group_ids = SiteSetting.chat_allowed_groups_map
      everyone_allowed = group_ids.include?(Group::AUTO_GROUPS[:everyone])
      max_users = SiteSetting.max_chat_auto_joined_users
      now = Time.zone.now
      last_seen_at = 30.days.ago

      # used to filter down to a specific user, chat channel, or category
      user_sql = params.user_id ? "AND u.id = #{params.user_id}" : ""
      channel_sql = params.channel_id ? "AND cc.id = #{params.channel_id}" : ""
      category_sql = params.category_id ? "AND c.id = #{params.category_id}" : ""

      sql = <<~SQL
        WITH chat_users AS ( -- users that are allowed to join chat
          SELECT u.id
            FROM users u
            JOIN user_options uo ON uo.user_id = u.id AND uo.chat_enabled = TRUE
           WHERE u.id > 0
             AND u.active = TRUE
             AND u.staged = FALSE
             AND (u.suspended_till IS NULL OR u.suspended_till <= :now)
             AND (u.silenced_till IS NULL OR u.silenced_till <= :now)
             AND NOT EXISTS (SELECT 1 FROM anonymous_users au WHERE au.user_id = u.id)
             AND u.last_seen_at > :last_seen_at
             #{user_sql}
             #{everyone_allowed ? "" : "AND EXISTS (SELECT 1 FROM group_users gu WHERE gu.user_id = u.id AND gu.group_id IN (:group_ids))"}
           ORDER BY u.last_seen_at DESC
           LIMIT :max_users
        ), valid_chat_channels AS ( -- auto joinable chat channels
          SELECT cc.id, cc.chatable_id
            FROM chat_channels cc
           WHERE cc.auto_join_users = TRUE
             AND cc.chatable_type = 'Category'
             AND cc.deleted_at IS NULL
             AND cc.user_count < :max_users
             #{channel_sql}
        ), public AS ( -- public chat channels
          SELECT cu.id AS user_id, cc.id AS chat_channel_id
            FROM valid_chat_channels cc
            CROSS JOIN chat_users cu
            JOIN categories c ON c.id = cc.chatable_id AND c.read_restricted = FALSE #{category_sql}
        ), private AS ( -- private chat channels
          SELECT DISTINCT gu.user_id, cc.id AS chat_channel_id
            FROM valid_chat_channels cc
            JOIN categories c ON c.id = cc.chatable_id AND c.read_restricted = TRUE #{category_sql}
            JOIN category_groups cg ON cg.category_id = c.id AND cg.permission_type IN (:group_permissions)
            JOIN group_users gu ON gu.group_id = cg.group_id AND gu.user_id IN (SELECT id FROM chat_users)
        )
        INSERT INTO user_chat_channel_memberships (user_id, chat_channel_id, following, join_mode, created_at, updated_at)
        SELECT p.user_id, p.chat_channel_id, TRUE, :automatic, :now, :now
          FROM (
            SELECT * FROM public
            UNION ALL
            SELECT * FROM private
          ) p
          LEFT JOIN user_chat_channel_memberships uccm ON uccm.user_id = p.user_id AND uccm.chat_channel_id = p.chat_channel_id
         WHERE uccm.user_id IS NULL
        RETURNING chat_channel_id, user_id
      SQL

      channel_to_users = Hash.new { |h, k| h[k] = [] }
      args = { now:, last_seen_at:, group_ids:, max_users:, group_permissions:, automatic: }

      DB
        .query_array(sql, args)
        .each { |channel_id, user_id| channel_to_users[channel_id] << user_id }

      ::Chat::Channel
        .where(id: channel_to_users.keys)
        .find_each do |channel|
          ::Chat::ChannelMembershipManager.new(channel).recalculate_user_count
          ::Chat::Publisher.publish_new_channel(channel, channel_to_users[channel.id])
        end
    end
  end
end
