# frozen_string_literal: true

module Chat
  class ChatableUserSerializer < BasicUserSerializer
    attributes :can_chat

    def can_chat
      true
    end

    def include_can_chat?
      object.can_chat
    end
  end
end
