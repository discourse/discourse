# frozen_string_literal: true

module Chat
  class PinnedMessageSerializer < ::ApplicationSerializer
    attributes :id, :chat_message_id, :pinned_at, :excerpt

    has_one :pinned_by, serializer: ::BasicUserSerializer, embed: :objects
    has_one :message, serializer: Chat::MessageSerializer, embed: :objects

    def pinned_at
      object.created_at
    end

    # the stored excerpt strips links because most surfaces showing it are
    # themselves links or buttons; the pinned bar can host them, so it gets its own
    def excerpt
      object.chat_message.build_excerpt(strip_links: false)
    end

    def pinned_by
      object.user
    end

    def message
      object.chat_message
    end
  end
end
