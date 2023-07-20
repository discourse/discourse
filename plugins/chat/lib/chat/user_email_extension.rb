# frozen_string_literal: true

module Chat
  module UserEmailExtension
    def execute(args)
      super(args)

      if args[:type] == "chat_summary" && args[:memberships_to_update_data].present?
        args[:memberships_to_update_data].to_a.each do |membership_id, max_unread_mention_id|
          Chat::UserChatChannelMembership.find_by(
            user: args[:user_id],
            id: membership_id.to_i,
          )&.update(last_unread_mention_when_emailed_id: max_unread_mention_id.to_i)
        end
      end
    end
  end
end
