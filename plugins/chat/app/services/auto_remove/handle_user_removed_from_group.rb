# frozen_string_literal: true

module Chat
  module Service
    module AutoRemove
      class HandleUserRemovedFromGroup
        include Service::Base

        contract
        model :user
        step :remove_if_outside_chat_allowed_groups
        step :remove_from_private_channels

        class Contract
          attribute :user_id
        end

        private

        def fetch_user(contract:, **)
          User.find(contract.user_id)
        end

        def remove_if_outside_chat_allowed_groups(user:, **)
          return if user.staff?

          # if the group the user was removed from is one of the chat allowed
          # groups, check if they are still in any of the other chat allowed
          # groups, otherwise kick
          if !GroupUser.exists?(group_id: SiteSetting.chat_allowed_groups_map, user: user)
            # TODO (martin) Maybe extract this to a single user version?
            UserChatChannelMembership
              .joins(:chat_channel)
              .where(user_id: user.id)
              .where.not(chat_channel: { type: "DirectMessageChannel" })
              .delete_all
          end
        end

        def remove_from_private_channels(user:, **)
          return noop if user.staff?

          # get a map of all groups that are allowed to access the channels the
          # user is a member of and their permission level. for channels where
          # the user is not a member of any valid groups anymore, kick them out
          channel_group_permission_map = DB.query(<<~SQL)
            SELECT chat_channels.id AS channel_id,
                   chat_channels.chatable_id AS category_id,
                   category_groups.group_id,
                   category_groups.permission_type
            FROM chat_channels
            INNER JOIN categories ON categories.id = chat_channels.chatable_id AND chat_channels.chatable_type = 'Category'
            INNER JOIN category_groups ON category_groups.category_id = categories.id
          SQL

          channel_ids = channel_group_permission_map.map(&:channel_id).uniq
          user_memberships =
            UserChatChannelMembership.where(chat_channel_id: channel_ids, user: user)

          membership_ids_to_delete = []
          user_memberships.each do |membership|
            # if the user has permission to see + reply with any of the channel groups,
            # then they are safe
            see_and_reply_group_ids =
              channel_group_permission_map
                .select { |cgm| cgm.channel_id == membership.chat_channel_id }
                .select { |cgm| cgm.permission_type < CategoryGroup.permission_types[:readonly] }
                .map(&:group_id)
            next if user.in_any_groups?(see_and_reply_group_ids)

            membership_ids_to_delete << membership.id
          end

          return noop if membership_ids_to_delete.empty?

          UserChatChannelMembership.where(id: membership_ids_to_delete).delete_all

          context.merge(users_removed: membership_ids_to_delete.length)
        end

        def noop
          context.merge(users_removed: 0)
        end
      end
    end
  end
end
