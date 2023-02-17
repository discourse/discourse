# frozen_string_literal: true

module Chat
  module Service
    module AutoRemove
      class UserRemovedFromGroup
        include Service::Base

        contract
        step :execute

        class Contract
          attribute :user
          attribute :group
        end

        private

        def execute(contract:, **)
          # if the group the user was removed from is one of the chat allowed groups, check if they are still in any of the other chat allowed groups, otherwise kick

          # get a map of all groups that are allowed to access the channels the user is a member of and their permission level. for channels where the user is
          # not a member of any valid groups anymore, kick
          channel_group_map = DB.query(<<~SQL)
          SELECT chat_channels.id AS channel_id, chat_channels.chatable_id AS category_id, category_groups.group_id, category_groups.permission_type
          FROM chat_channels
          INNER JOIN categories ON categories.id = chat_channels.chatable_id AND chat_channels.chatable_type = 'Category'
          INNER JOIN category_groups ON category_groups.category_id = categories.id
        SQL

          channel_ids = channel_group_map.map(&:channel_id).uniq
          user_memberships =
            UserChatChannelMembership.where(chat_channel_id: channel_ids, user: contract.user)

          membership_ids_to_delete = []
          user_memberships.each do |membership|
            channel_group_permissions =
              channel_group_map.select { |cgm| cgm.channel_id == membership.chat_channel_id }

            # if the user is in none of the groups then they need to be kicked out
            if !contract.user.in_any_groups?(channel_group_permissions.map(&:group_id))
              membership_ids_to_delete << membership.id
              next
            end

            # if the user has permission to reply with any of the channel groups,
            # then they are safe
            if channel_group_permissions.any? { |cgm|
                 cgm.permission_type < CategoryGroup.permission_types[:readonly]
               }
              next
            end

            membership_ids_to_delete << membership.id
          end

          UserChatChannelMembership.where(id: membership_ids_to_delete).delete_all

          context.merge(users_removed: membership_ids_to_delete.length)
        end
      end
    end
  end
end
