# frozen_string_literal: true

module Chat
  class PinnedMessageSerializer < ::ApplicationSerializer
    attributes :id, :chat_message_id, :pinned_at

    has_one :pinned_by, serializer: ::BasicUserSerializer, embed: :objects
    has_one :message, serializer: Chat::MessageSerializer, embed: :objects

    def pinned_at
      object.created_at
    end

    def pinned_by
      object.user
    end

    def message
      object.chat_message
    end
  end
end
