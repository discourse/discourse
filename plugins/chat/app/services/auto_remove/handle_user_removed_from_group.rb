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

        policy :chat_enabled
        policy :not_everyone_allowed
        contract
        model :user
        policy :user_not_staff
        model :memberships_to_remove
        step :remove_memberships
        step :publish

        class Contract
          attribute :user_id, :integer

          validates :user_id, presence: true
        end

        private

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

        def fetch_memberships_to_remove(user:, **)
          UserChatChannelMembership
            .joins(:chat_channel)
            .where(id: Actions::CalculateMembershipsForRemoval.call(scoped_users: [user]))
            .then do |memberships|
              if SiteSetting.chat_allowed_groups_map.present? &&
                   GroupUser.exists?(group_id: SiteSetting.chat_allowed_groups_map, user: user)
                break memberships
              end
              memberships.or(
                UserChatChannelMembership
                  .joins(:chat_channel)
                  .where(user_id: user.id)
                  .where.not(chat_channel: { type: "DirectMessageChannel" }),
              )
            end
        end

        def remove_memberships(memberships_to_remove:, **)
          context[:users_removed_map] = Actions::RemoveMemberships.call(
            memberships: memberships_to_remove,
          )
        end

        def publish(users_removed_map:, **)
          Chat::Service::Actions::PublishAutoRemovedUser.call(
            event_type: :user_removed_from_group,
            users_removed_map: users_removed_map,
          )
        end
      end
    end
  end
end
