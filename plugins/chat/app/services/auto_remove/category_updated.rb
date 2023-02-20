# frozen_string_literal: true

module Chat
  module Service
    module AutoRemove
      class CategoryUpdated
        include Service::Base

        contract
        model :category_channel_ids
        step :execute

        class Contract
          attribute :category
        end

        private

        def fetch_category_channel_ids(contract:, **)
          ChatChannel.where(chatable: contract.category).pluck(:id)
        end

        def execute(contract:, category_channel_ids:, **)
          return noop if !contract.category.read_restricted?
          return noop if category_channel_ids.empty?

          # if the category doesn't have any secure group IDs anymore,
          # then anyone who is a non-staff user will be kicked out of any
          # corresponding category channels_to_add
          #
          # if the category does have secure group IDs still, then only non-staff
          # users who are not in groups with reply + see permission for the
          # corresponding category channels will be kicked out
          reply_and_see_permission_group_ids =
            if contract.category.secure_group_ids.none?
              []
            else
              # find all groups that can reply + see (reply_and_see permisson) for
              # category, and any users NOT in any of those groups must be
              # kicked
              Group
                .joins("INNER JOIN category_groups ON category_groups.group_id = groups.id")
                .where("category_groups.group_id IN (?)", contract.category.secure_group_ids)
                .where("category_groups.category_id = ?", contract.category.id)
                .where(
                  "category_groups.permission_type < ?",
                  CategoryGroup.permission_types[:readonly], # create_post and full are 1 and 2, readonly is 3
                )
                .pluck(:group_id)
            end

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
                WHERE group_users.group_id IN (#{reply_and_see_permission_group_ids})
              )
            SQL
            users = users.where(group_user_sql)
          end

          user_ids_to_remove = users.distinct.pluck(:id)
          return noop if user_ids_to_remove.empty?

          UserChatChannelMembership
            .joins(:chat_channel)
            .where(user_id: user_ids_to_remove)
            .where(chat_channel_id: category_channel_ids)
            .delete_all

          context.merge(users_removed: user_ids_to_remove.length)
        end

        def noop
          context.merge(users_removed: 0)
        end
      end
    end
  end
end
