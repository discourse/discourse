# frozen_string_literal: true

module Chat
  module Service
    module AutoRemove
      class HandleDestroyedGroup
        include Service::Base

        contract
        model :scoped_users
        step :remove_users_outside_allowed_groups
        step :remove_users_without_channel_permission
        step :publish

        class Contract
          attribute :destroyed_group_user_ids
        end

        private

        def fetch_scoped_users(destroyed_group_user_ids:, **)
          User
            .real
            .activated
            .not_suspended
            .not_staged
            .includes(:group_users)
            .where("NOT admin AND NOT moderator")
            .where(id: destroyed_group_user_ids)
            .joins(:user_chat_channel_memberships)
            .distinct
        end

        def remove_users_outside_allowed_groups(scoped_users:, **)
          return noop if SiteSetting.chat_allowed_groups_map.include?(Group::AUTO_GROUPS[:everyone])

          users = scoped_users

          # Remove any of these users from all category channels if they
          # are not in any of the chat_allowed_groups or if there are no
          # chat allowed groups.
          if SiteSetting.chat_allowed_groups_map.any?
            group_user_sql = <<~SQL
              users.id NOT IN (
                SELECT DISTINCT group_users.user_id
                FROM group_users
                WHERE group_users.group_id IN (#{SiteSetting.chat_allowed_groups_map.join(",")})
              )
            SQL
            users = users.where(group_user_sql)
          end

          user_ids_to_remove = users.pluck(:id)
          return noop if user_ids_to_remove.empty?

          memberships_to_remove =
            UserChatChannelMembership
              .joins(:chat_channel)
              .where(user_id: user_ids_to_remove)
              .where.not(chat_channel: { type: "DirectMessageChannel" })

          users_removed_map =
            memberships_to_remove
              .destroy_all
              .each_with_object({}) do |obj, hash|
                hash[obj.chat_channel_id] = [] if !hash.key? obj.chat_channel_id
                hash[obj.chat_channel_id] << obj.user_id
              end

          context.merge(users_removed_map: users_removed_map)
        end

        def remove_users_without_channel_permission(scoped_users:, **)
          channel_permissions_map =
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
            GROUP BY chat_channels.id, chat_channels.chatable_id, categories.read_restricted
            ORDER BY channel_id
          SQL

          scoped_memberships =
            UserChatChannelMembership
              .joins(:chat_channel)
              .where(user: scoped_users)
              .where(chat_channel_id: channel_permissions_map.map(&:channel_id))

          memberships_to_remove = []
          scoped_memberships.find_each do |membership|
            scoped_user = scoped_users.find { |su| su.id == membership.user_id }
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
              channel_permission.groups_with_write_permissions&.split(",")&.map(&:to_i) || []
            group_ids_with_read_permission =
              channel_permission.groups_with_readonly_permissions&.split(",")&.map(&:to_i) || []

            # None of the groups on the channel have permission to do anything
            # more than read only, remove the membership.
            if group_ids_with_write_permission.empty? && group_ids_with_read_permission.any?
              memberships_to_remove << membership.id
              next
            end

            # At least one of the groups on the channel can create_post or
            # has full permission, remove the membership if the user is in none
            # of these groups.
            if group_ids_with_write_permission.any? &&
                 !scoped_user.in_any_groups?(group_ids_with_write_permission)
              memberships_to_remove << membership.id
            end
          end

          return noop if memberships_to_remove.empty?

          users_removed_map =
            UserChatChannelMembership
              .where(id: memberships_to_remove)
              .destroy_all
              .each_with_object({}) do |obj, hash|
                hash[obj.chat_channel_id] = [] if !hash.key? obj.chat_channel_id
                hash[obj.chat_channel_id] << obj.user_id
              end

          context.merge(users_removed_map: users_removed_map)
        end

        def publish(users_removed_map:, **)
          Chat::Service::Actions::AutoRemovedUserPublisher.call(
            event_type: :destroyed_group,
            users_removed_map: users_removed_map,
          )
        end

        def noop
          context.merge(users_removed_map: context.users_removed_map || {})
        end
      end
    end
  end
end
