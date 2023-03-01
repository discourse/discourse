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

        policy :chat_enabled
        policy :not_everyone_allowed
        contract
        model :scoped_users
        step :fetch_users
        model :memberships_to_remove
        step :remove_memberships
        step :publish

        class Contract
          attribute :destroyed_group_user_ids

          validates :destroyed_group_user_ids, presence: true
        end

        private

        def chat_enabled
          SiteSetting.chat_enabled
        end

        def not_everyone_allowed
          !SiteSetting.chat_allowed_groups_map.include?(Group::AUTO_GROUPS[:everyone])
        end

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

        def fetch_users(scoped_users:, **)
          context[:users] = scoped_users.then do |users|
            break users if SiteSetting.chat_allowed_groups_map.blank?
            users.where(<<~SQL, SiteSetting.chat_allowed_groups_map)
              users.id NOT IN (
                SELECT DISTINCT group_users.user_id
                FROM group_users
                WHERE group_users.group_id IN (?)
              )
            SQL
          end
        end

        def fetch_memberships_to_remove(scoped_users:, users:, **)
          UserChatChannelMembership
            .joins(:chat_channel)
            .where(user_id: users.pluck(:id))
            .where.not(chat_channel: { type: "DirectMessageChannel" })
            .or(
              UserChatChannelMembership.where(
                id: Actions::CalculateMembershipsForRemoval.call(scoped_users: scoped_users),
              ),
            )
        end

        def remove_memberships(memberships_to_remove:, **)
          context[:users_removed_map] = Actions::RemoveMemberships.call(
            memberships: memberships_to_remove,
          )
        end

        def publish(users_removed_map:, **)
          Chat::Service::Actions::PublishAutoRemovedUser.call(
            event_type: :destroyed_group,
            users_removed_map: users_removed_map,
          )
        end
      end
    end
  end
end
