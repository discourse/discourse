# frozen_string_literal: true

module Chat
  module Service
    module AutoRemove
      class OutsideChatAllowedGroups
        include Service::Base

        contract
        step :execute

        class Contract
          attribute :old_allowed_groups
          attribute :new_allowed_groups

          before_validation do
            self.old_allowed_groups = self.old_allowed_groups.to_s.split("|")
            self.new_allowed_groups = self.new_allowed_groups.to_s.split("|")
          end
        end

        private

        def execute(contract:, **)
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
            allowed_sql = <<~SQL
              users.id NOT IN (
                SELECT DISTINCT group_users.user_id
                FROM group_users
                WHERE group_users.group_id IN (#{contract.new_allowed_groups.join(",")})
              )
            SQL
            users = users.where(allowed_sql)
          end

          user_ids_to_remove = users.pluck(:id)

          UserChatChannelMembership
            .joins(:chat_channel)
            .where(user_id: user_ids_to_remove)
            .where.not(chat_channel: { type: "DirectMessageChannel" })
            .delete_all

          context.merge(users_removed: user_ids_to_remove.length)
        end
      end
    end
  end
end
