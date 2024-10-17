# frozen_string_literal: true

module Chat
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

      policy :chat_enabled
      contract do
        attribute :category_id, :integer

        validates :category_id, presence: true
      end
      step :assign_defaults
      model :category
      model :category_channel_ids
      model :users
      step :remove_users_without_channel_permission
      step :publish

      private

      def assign_defaults
        context[:users_removed_map] = {}
      end

      def chat_enabled
        SiteSetting.chat_enabled
      end

      def fetch_category(contract:)
        Category.find_by(id: contract.category_id)
      end

      def fetch_category_channel_ids(category:)
        Chat::Channel.where(chatable: category).pluck(:id)
      end

      def fetch_users(category_channel_ids:)
        User
          .real
          .activated
          .not_suspended
          .not_staged
          .joins(:user_chat_channel_memberships)
          .where("user_chat_channel_memberships.chat_channel_id IN (?)", category_channel_ids)
          .where("NOT admin AND NOT moderator")
      end

      def remove_users_without_channel_permission(users:, category_channel_ids:)
        memberships_to_remove =
          Chat::Action::CalculateMembershipsForRemoval.call(
            scoped_users_query: users,
            channel_ids: category_channel_ids,
          )

        return if memberships_to_remove.blank?

        context[:users_removed_map] = Chat::Action::RemoveMemberships.call(
          memberships: Chat::UserChatChannelMembership.where(id: memberships_to_remove),
        )
      end

      def publish(users_removed_map:)
        Chat::Action::PublishAutoRemovedUser.call(
          event_type: :category_updated,
          users_removed_map: users_removed_map,
        )
      end
    end
  end
end
