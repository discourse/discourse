# frozen_string_literal: true

module Chat
  class BaseThreadMembershipSerializer < ApplicationSerializer
    attributes :notification_level, :thread_id, :last_read_message_id

    def notification_level
      Chat::UserChatThreadMembership.notification_levels[object.notification_level] ||
        Chat::UserChatThreadMembership.notification_levels["normal"]
    end
  end
end
