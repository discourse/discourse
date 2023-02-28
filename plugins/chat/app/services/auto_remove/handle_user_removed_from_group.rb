# frozen_string_literal: true

module Chat
  module Service
    module AutoRemove
      # Fired from [Jobs::AutoRemoveMembershipHandleUserRemovedFromGroup], which
      # in turn is enqueued whenever the [DiscourseEvent] for :user_removed_from_group
      # is triggered.
      #
      # Staff users will never be affected by this, they can always chat regardless
      # of group permissions.
      #
      # Since this could have potential wide-ranging impact, we have to check:
      #   * The chat_allowed_groups [SiteSetting], and if the scoped user
      #     is still allowed to use public chat channels based on this setting.
      #   * The channel permissions of all the category chat channels the user
      #     is a part of, based on [CategoryGroup] records
      #
      # Direct message channel memberships are intentionally left alone,
      # these are private communications between two people.
      class HandleUserRemovedFromGroup
        include Service::Base

        contract
        model :user
        step :remove_if_outside_chat_allowed_groups
        step :remove_from_private_channels
        step :publish

        class Contract
          attribute :user_id
        end

        private

        def fetch_user(contract:, **)
          User.find_by(id: contract.user_id)
        end

        def remove_if_outside_chat_allowed_groups(user:, **)
          return noop if user.staff?
          return noop if SiteSetting.chat_allowed_groups_map.include?(Group::AUTO_GROUPS[:everyone])

          if !GroupUser.exists?(group_id: SiteSetting.chat_allowed_groups_map, user: user)
            memberships_to_remove =
              UserChatChannelMembership
                .joins(:chat_channel)
                .where(user_id: user.id)
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
        end

        def remove_from_private_channels(user:, **)
          return noop if user.staff?

          memberships_to_remove =
            Chat::Service::Actions::CalculateMembershipsForRemoval.call(scoped_users: [user])

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
            event_type: :user_removed_from_group,
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
