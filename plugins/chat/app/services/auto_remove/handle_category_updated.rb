# frozen_string_literal: true

module Chat
  module Service
    module AutoRemove
      # Fired from [Jobs::AutoRemoveMembershipHandleCategoryUpdated], which
      # in turn is enqueued whenever the [DiscourseEvent] for :category_updated
      # is triggered. Any users who can no longer access category-based channels
      # based on category_groups and in turn group_users will be removed from
      # those chat channels.
      #
      # If a user is in any groups that have the `full` or `create_post`
      # [CategoryGroup#permission_types] or if the category has no groups remaining,
      # then the user will remain in the channel.
      class HandleCategoryUpdated
        include Service::Base

        contract
        model :category
        model :category_channel_ids
        step :remove_users_without_channel_permission
        step :publish

        class Contract
          attribute :category_id
        end

        private

        def fetch_category(contract:, **)
          Category.find_by(id: contract.category_id)
        end

        def fetch_category_channel_ids(category:, **)
          ChatChannel.where(chatable: category).pluck(:id)
        end

        def remove_users_without_channel_permission(category:, category_channel_ids:, **)
          return noop if category_channel_ids.empty?

          users =
            User
              .real
              .activated
              .not_suspended
              .not_staged
              .joins(:user_chat_channel_memberships)
              .where("user_chat_channel_memberships.chat_channel_id IN (?)", category_channel_ids)
              .where("NOT admin AND NOT moderator")

          memberships_to_remove =
            Chat::Service::Actions::CalculateMembershipsForRemoval.call(
              scoped_users: users,
              channel_ids: category_channel_ids,
            )

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
            event_type: :category_updated,
            users_removed_map: users_removed_map,
          )
        end

        def noop
          context.merge(users_removed_map: {})
        end
      end
    end
  end
end
