# frozen_string_literal: true

module Chat
  class ChatableGroupSerializer < BasicGroupSerializer
    attributes :chat_enabled, :chat_enabled_user_count, :can_chat

    def chat_enabled
      SiteSetting.chat_enabled
    end

    def chat_enabled_user_count
      object.users.count { |user| user.user_option&.chat_enabled }
    end

    def can_chat
      chat_enabled && chat_enabled_user_count <= SiteSetting.chat_max_direct_message_users
    end
  end
end
