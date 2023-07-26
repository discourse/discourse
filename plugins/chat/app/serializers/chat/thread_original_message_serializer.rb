# frozen_string_literal: true

module Chat
  class ThreadOriginalMessageSerializer < Chat::MessageSerializer
    has_one :user, serializer: BasicUserWithStatusSerializer, embed: :objects

    def excerpt
      object.censored_excerpt(max_length: Chat::Thread::EXCERPT_LENGTH)
    end

    def include_available_flags?
      false
    end

    def include_reactions?
      false
    end

    def include_edited?
      false
    end

    def include_in_reply_to?
      false
    end

    def include_user_flag_status?
      false
    end

    def include_uploads?
      false
    end

    def include_bookmark?
      false
    end

    def include_chat_webhook_event?
      false
    end
  end
end
