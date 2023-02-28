# frozen_string_literal: true

module Chat
  module Service
    module AutoRemove
      class HandleChatAllowedGroupsChange
        include Service::Base

        contract
        step :remove_users_outside_allowed_groups
        step :publish

        class Contract
          attribute :new_allowed_groups

          before_validation do
            self.new_allowed_groups = self.new_allowed_groups.to_s.split("|").map(&:to_i)
          end
        end

        private

        def remove_users_outside_allowed_groups(contract:, **)
          return noop if contract.new_allowed_groups.include?(Group::AUTO_GROUPS[:everyone])

          users =
            User
              .real
              .activated
              .not_suspended
              .not_staged
              .where("NOT admin AND NOT moderator")
              .joins(:user_chat_channel_memberships)
              .distinct

          if contract.new_allowed_groups.any?
            group_user_sql = <<~SQL
              users.id NOT IN (
                SELECT DISTINCT group_users.user_id
                FROM group_users
                WHERE group_users.group_id IN (#{contract.new_allowed_groups.join(",")})
              )
            SQL
            users = users.where(group_user_sql)
          end

          user_ids_to_remove = users.pluck(:id)
          return noop if user_ids_to_remove.empty?

          memberships_to_remove =
            UserChatChannelMembership
              .joins(:chat_channel)
              .where(user_id: user_ids_to_remove)
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

        def publish(users_removed_map:, **)
          Chat::Service::Actions::AutoRemovedUserPublisher.call(
            event_type: :chat_allowed_groups_changed,
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
