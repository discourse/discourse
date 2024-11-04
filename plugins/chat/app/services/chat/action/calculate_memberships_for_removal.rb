# frozen_string_literal: true

module Chat
  module Action
    # There is significant complexity around category channel permissions,
    # since they are inferred from [CategoryGroup] records and their corresponding
    # permission types.
    #
    # To be able to join and chat in a channel, a user must either be staff,
    # or be in a group that has either `full` or `create_post` permissions
    # via [CategoryGroup].
    #
    # However, there is an edge case. If there are no [CategoryGroup] records
    # for a given category, this means that the [Group::AUTO_GROUPS[:everyone]]
    # group has `full` access to the channel, therefore everyone can post in
    # the chat channel (so long as they are in one of the `SiteSetting.chat_allowed_groups`)
    #
    # Here, we can efficiently query the channel category permissions and figure
    # out which of the users provided should have their [Chat::UserChatChannelMembership]
    # records removed based on those security cases.
    class CalculateMembershipsForRemoval < Service::ActionBase
      option :scoped_users_query
      option :channel_ids, [], optional: true

      def call
        memberships_to_remove = []
        scoped_memberships.find_each do |membership|
          channel_permission =
            channel_permissions_map.find { |cpm| cpm.channel_id == membership.chat_channel_id }

          # If there is no channel in the map, this means there are no
          # category_groups for the channel.
          #
          # This in turn means the Everyone group with full permission
          # is the only group that can access the channel (no category_group
          # record is created in this case), we do not need to remove any users.
          next if channel_permission.blank?

          group_ids_with_write_permission =
            channel_permission.groups_with_write_permissions.to_s.split(",").map(&:to_i)
          group_ids_with_read_permission =
            channel_permission.groups_with_readonly_permissions.to_s.split(",").map(&:to_i)

          # None of the groups on the channel have permission to do anything
          # more than read only, remove the membership.
          if group_ids_with_write_permission.empty? && group_ids_with_read_permission.any?
            memberships_to_remove << membership.id
            next
          end

          # At least one of the groups on the channel can create_post or
          # has full permission, remove the membership if the user is in none
          # of these groups.
          if group_ids_with_write_permission.any?
            scoped_user = scoped_users_query.where(id: membership.user_id).first

            if !scoped_user&.in_any_groups?(group_ids_with_write_permission)
              memberships_to_remove << membership.id
            end
          end
        end

        memberships_to_remove
      end

      private

      def channel_permissions_map
        @channel_permissions_map ||=
          DB.query(<<~SQL, readonly: CategoryGroup.permission_types[:readonly])
          WITH category_group_channel_map AS (
            SELECT category_groups.group_id,
              category_groups.permission_type,
              chat_channels.id AS channel_id
            FROM category_groups
            INNER JOIN categories ON categories.id = category_groups.category_id
            INNER JOIN chat_channels ON categories.id = chat_channels.chatable_id
              AND chat_channels.chatable_type = 'Category'
          )

          SELECT chat_channels.id AS channel_id,
            chat_channels.chatable_id AS category_id,
            (
              SELECT string_agg(category_group_channel_map.group_id::varchar, ',')
              FROM category_group_channel_map
              WHERE category_group_channel_map.permission_type < :readonly AND
                category_group_channel_map.channel_id = chat_channels.id
            ) AS groups_with_write_permissions,
              (
              SELECT string_agg(category_group_channel_map.group_id::varchar, ',')
              FROM category_group_channel_map
              WHERE category_group_channel_map.permission_type = :readonly AND
                category_group_channel_map.channel_id = chat_channels.id
            ) AS groups_with_readonly_permissions,
            categories.read_restricted
            FROM category_group_channel_map
            INNER JOIN chat_channels ON chat_channels.id = category_group_channel_map.channel_id
            INNER JOIN categories ON categories.id = chat_channels.chatable_id
            WHERE chat_channels.chatable_type = 'Category'
            #{channel_ids.present? ? "AND chat_channels.id IN (#{channel_ids.join(",")})" : ""}
            GROUP BY chat_channels.id, chat_channels.chatable_id, categories.read_restricted
            ORDER BY channel_id
          SQL
      end

      def scoped_memberships
        @scoped_memberships ||=
          Chat::UserChatChannelMembership
            .joins(:chat_channel)
            .where(user_id: scoped_users_query.select(:id))
            .where(chat_channel_id: channel_permissions_map.map(&:channel_id))
      end
    end
  end
end
