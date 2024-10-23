# frozen_string_literal: true

module Chat
  module AutoRemove
    # Fired from [Jobs::AutoRemoveMembershipHandleChatAllowedGroupsChange], which
    # in turn is enqueued whenever the [DiscourseEvent] for :site_setting_changed
    # is triggered for the chat_allowed_groups setting.
    #
    # If any of the chat_allowed_groups is the everyone auto group then nothing
    # needs to be done.
    #
    # Otherwise, if there are no longer any chat_allowed_groups, we have to
    # remove all non-admin users from category channels. Otherwise we just
    # remove the ones who are not in any of the chat_allowed_groups.
    #
    # Direct message channel memberships are intentionally left alone,
    # these are private communications between two people.
    class HandleChatAllowedGroupsChange
      include Service::Base

      policy :chat_enabled
      contract { attribute :new_allowed_groups, :array }
      policy :not_everyone_allowed
      model :users
      model :memberships_to_remove
      step :remove_users_outside_allowed_groups
      step :publish

      private

      def chat_enabled
        SiteSetting.chat_enabled
      end

      def not_everyone_allowed(contract:)
        contract.new_allowed_groups.exclude?(Group::AUTO_GROUPS[:everyone])
      end

      def fetch_users(contract:)
        User
          .real
          .activated
          .not_suspended
          .not_staged
          .where("NOT admin AND NOT moderator")
          .joins(:user_chat_channel_memberships)
          .distinct
          .then do |users|
            break users if contract.new_allowed_groups.blank?
            users.where(<<~SQL, contract.new_allowed_groups)
                users.id NOT IN (
                  SELECT DISTINCT group_users.user_id
                  FROM group_users
                  WHERE group_users.group_id IN (?)
                )
              SQL
          end
      end

      def fetch_memberships_to_remove(users:)
        Chat::UserChatChannelMembership
          .joins(:chat_channel)
          .where(user_id: users.pluck(:id))
          .where.not(chat_channel: { type: "DirectMessageChannel" })
      end

      def remove_users_outside_allowed_groups(memberships_to_remove:)
        context[:users_removed_map] = Chat::Action::RemoveMemberships.call(
          memberships: memberships_to_remove,
        )
      end

      def publish(users_removed_map:)
        Chat::Action::PublishAutoRemovedUser.call(
          event_type: :chat_allowed_groups_changed,
          users_removed_map: users_removed_map,
        )
      end
    end
  end
end
