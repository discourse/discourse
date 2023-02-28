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
        step :publish

        class Contract
          attribute :user_id
        end

        private

        def fetch_user(contract:, **)
          User.find_by(id: contract.user_id)
        end

        def remove_if_outside_chat_allowed_groups(user:, **)
          return noop if user.staff?
          return noop if SiteSetting.chat_allowed_groups_map.include?(Group::AUTO_GROUPS[:everyone])

          if !GroupUser.exists?(group_id: SiteSetting.chat_allowed_groups_map, user: user)
            memberships_to_remove =
              UserChatChannelMembership
                .joins(:chat_channel)
                .where(user_id: user.id)
                .where.not(chat_channel: { type: "DirectMessageChannel" })

            users_removed_map =
              memberships_to_remove
                .destroy_all
                .each_with_object({}) do |obj, hash|
                  hash[obj.chat_channel_id] = [] if !hash.key? obj.chat_channel_id
                  hash[obj.chat_channel_id] << obj.user_id
                end

            context.merge(users_removed_map: users_removed_map)
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

          user_memberships =
            UserChatChannelMembership.where(
              chat_channel_id: channel_group_permission_map.map(&:channel_id).uniq,
              user: user,
            )

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

          memberships_to_remove = UserChatChannelMembership.where(id: membership_ids_to_delete)

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
            event_type: :user_removed_from_group,
            users_removed_map: users_removed_map,
          )
        end

        def noop
          context.merge(users_removed_map: context.users_removed_map || {})
        end
      end
    end
  end
end
