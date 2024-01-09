# frozen_string_literal: true

module Chat
  class ChatableGroupSerializer < BasicGroupSerializer
    attributes :can_chat

    def can_chat
      SiteSetting.chat_enabled
    end
  end
end
