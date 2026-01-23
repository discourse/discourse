# frozen_string_literal: true

module Chat
  class PinnedMessageSerializer < ::ApplicationSerializer
    attributes :id, :chat_message_id, :pinned_at, :pinned_by_id

    has_one :message, serializer: Chat::MessageSerializer, embed: :objects

    def pinned_at
      object.created_at
    end

    def message
      object.chat_message
    end
  end
end
