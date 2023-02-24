# frozen_string_literal: true

module Chat
  module Service
    module AutoRemove
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

          # find all groups that can reply + see (full/create_post permisson) for
          # category, and any users NOT in any of those groups must be kicked
          #
          # if the category doesn't have any group IDs anymore,
          # then anyone who is a non-staff user will be kicked out of any
          # corresponding category channels
          #
          # if the category does have category group IDs still, then only non-staff
          # users who are not in groups with reply + see permission for the
          # corresponding category channels will be kicked out
          reply_and_see_permission_group_ids =
            Group
              .joins("INNER JOIN category_groups ON category_groups.group_id = groups.id")
              .where("category_groups.category_id = ?", category.id)
              .where(
                "category_groups.permission_type < ?",
                CategoryGroup.permission_types[:readonly], # create_post and full are 1 and 2, readonly is 3
              )
              .pluck(:group_id)

          users =
            User
              .real
              .activated
              .not_suspended
              .not_staged
              .joins(:user_chat_channel_memberships)
              .where("user_chat_channel_memberships.chat_channel_id IN (?)", category_channel_ids)
              .where("NOT admin AND NOT moderator")

          if reply_and_see_permission_group_ids.any?
            group_user_sql = <<~SQL
              users.id NOT IN (
                SELECT DISTINCT group_users.user_id
                FROM group_users
                WHERE group_users.group_id IN (#{reply_and_see_permission_group_ids.join(",")})
              )
            SQL
            users = users.where(group_user_sql)
          end

          user_ids_to_remove = users.distinct.pluck(:id)
          return noop if user_ids_to_remove.empty?

          memberships_to_remove =
            UserChatChannelMembership
              .joins(:chat_channel)
              .where(user_id: user_ids_to_remove)
              .where(chat_channel_id: category_channel_ids)

          users_removed_map =
            memberships_to_remove
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
