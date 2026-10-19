# frozen_string_literal: true

module Chat
  class LastMessageSerializer < ::ApplicationSerializer
    # NOTE: The channel last message does not need to serialize relations
    # etc. at this point in time, since the only things we are using are
    # created_at and excerpt. In future we may want to serialize more, at which
    # point we need to check existing code so we don't introduce N1s.
    attributes *Chat::MessageSerializer::BASIC_ATTRIBUTES

    def created_at
      object.created_at.iso8601
    end

    def excerpt
      object.excerpt_for_display
    end
  end
end
