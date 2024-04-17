# frozen_string_literal: true

module Chat
  class BaseThreadMembershipSerializer < ApplicationSerializer
    attributes :notification_level, :thread_id, :last_read_message_id, :thread_title_prompt

    def notification_level
      Chat::UserChatThreadMembership.notification_levels[object.notification_level] ||
        Chat::UserChatThreadMembership.notification_levels["normal"]
    end

    def thread_title_prompt
      object.try(:thread_title_prompt) || false
    end
  end
end
