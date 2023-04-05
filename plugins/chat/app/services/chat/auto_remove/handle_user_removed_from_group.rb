# frozen_string_literal: true

module Chat
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
      step :assign_defaults
      policy :chat_enabled
      policy :not_everyone_allowed
      model :user
      policy :user_not_staff
      step :remove_if_outside_chat_allowed_groups
      step :remove_from_private_channels
      step :publish

      class Contract
        attribute :user_id, :integer

        validates :user_id, presence: true
      end

      private

      def assign_defaults
        context[:users_removed_map] = {}
      end

      def chat_enabled
        SiteSetting.chat_enabled
      end

      def not_everyone_allowed
        !SiteSetting.chat_allowed_groups_map.include?(Group::AUTO_GROUPS[:everyone])
      end

      def fetch_user(contract:, **)
        User.find_by(id: contract.user_id)
      end

      def user_not_staff(user:, **)
        !user.staff?
      end

      def remove_if_outside_chat_allowed_groups(user:, **)
        if SiteSetting.chat_allowed_groups_map.empty? ||
             !GroupUser.exists?(group_id: SiteSetting.chat_allowed_groups_map, user: user)
          memberships_to_remove =
            Chat::UserChatChannelMembership
              .joins(:chat_channel)
              .where(user_id: user.id)
              .where.not(chat_channel: { type: "DirectMessageChannel" })

          return if memberships_to_remove.empty?

          context[:users_removed_map] = Chat::Action::RemoveMemberships.call(
            memberships: memberships_to_remove,
          )
        end
      end

      def remove_from_private_channels(user:, **)
        memberships_to_remove =
          Chat::Action::CalculateMembershipsForRemoval.call(scoped_users: [user])

        return if memberships_to_remove.empty?

        context.merge(
          users_removed_map:
            Chat::Action::RemoveMemberships.call(
              memberships: Chat::UserChatChannelMembership.where(id: memberships_to_remove),
            ),
        )
      end

      def publish(users_removed_map:, **)
        Chat::Action::PublishAutoRemovedUser.call(
          event_type: :user_removed_from_group,
          users_removed_map: users_removed_map,
        )
      end
    end
  end
end
