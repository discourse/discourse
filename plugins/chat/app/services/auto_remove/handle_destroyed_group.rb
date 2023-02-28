# frozen_string_literal: true

module Chat
  module Service
    module AutoRemove
      # Fired from [Jobs::AutoRemoveMembershipHandleUserRemovedFromGroup], which
      # is in turn enqueued whenever the [DiscourseEvent] for :group_destroyed
      # is triggered.
      #
      # The :group_destroyed event provides us with the user_ids of the former
      # GroupUser records so we can scope this better.
      #
      # Since this could have potential wide-ranging impact, we have to check:
      #   * The chat_allowed_groups [SiteSetting], and if any of the scoped users
      #     are still allowed to use public chat channels based on this setting.
      #   * The channel permissions of all the category chat channels the users
      #     are a part of, based on [CategoryGroup] records
      #
      # If a user is in a groups that has the `full` or `create_post`
      # [CategoryGroup#permission_types] or if the category has no groups remaining,
      # then the user will remain in the channel.
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
          memberships_to_remove =
            Chat::Service::Actions::CalculateMembershipsForRemoval.call(scoped_users: scoped_users)

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
