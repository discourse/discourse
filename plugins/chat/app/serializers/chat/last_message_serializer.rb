# frozen_string_literal: true

module Chat
  class LastMessageSerializer < ::ApplicationSerializer
    # NOTE: The channel last message does not need to serialize relations
    # etc. at this point in time, since the only thing we are using is
    # created_at. In future we may want to serialize more for this, at which
    # point we need to check existing code so we don't introduce N1s.
    attributes *Chat::MessageSerializer::BASIC_ATTRIBUTES

    def created_at
      object.created_at.iso8601
    end
  end
end
