# frozen_string_literal: true

module Chat
  class ThreadOriginalMessageSerializer < Chat::MessageSerializer
    def excerpt
      WordWatcher.censor(object.rich_excerpt(max_length: Chat::Thread::EXCERPT_LENGTH))
    end
  end
end
