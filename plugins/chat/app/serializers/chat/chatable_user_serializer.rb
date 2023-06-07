# frozen_string_literal: true

module Chat
  class ChatableUserSerializer < BasicUserSerializer
    attributes :cannot_chat

    def cannot_chat
      true
    end

    def include_cannot_chat?
      object.cannot_chat
    end
  end
end
