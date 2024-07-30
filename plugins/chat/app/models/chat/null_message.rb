# frozen_string_literal: true

module Chat
  class NullMessage < Chat::Message
    def user
      nil
    end

    def build_excerpt
      nil
    end

    def id
      nil
    end

    def created_at
      Time.now # a proper NullTime object would be better, but this is good enough for now
    end
  end
end
