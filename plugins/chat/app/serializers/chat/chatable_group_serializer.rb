# frozen_string_literal: true

module Chat
  class ChatableGroupSerializer < BasicGroupSerializer
    attributes :chat_enabled, :chat_enabled_user_count, :can_chat

    def chat_enabled
      SiteSetting.chat_enabled
    end

    def chat_enabled_user_count
      @chat_enabled_user_count ||=
        object.human_users.joins(:user_option).where(user_options: { chat_enabled: true }).count
    end

    def can_chat
      # + 1 for current user
      chat_enabled && chat_enabled_user_count + 1 <= SiteSetting.chat_max_direct_message_users
    end
  end
end
