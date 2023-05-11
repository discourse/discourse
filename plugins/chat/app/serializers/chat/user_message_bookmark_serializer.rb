# frozen_string_literal: true

module Chat
  class UserMessageBookmarkSerializer < UserBookmarkBaseSerializer
    attr_reader :chat_message

    def title
      fancy_title
    end

    def fancy_title
      @fancy_title ||= chat_message.chat_channel.title(scope.user)
    end

    def cooked
      chat_message.cooked
    end

    def bookmarkable_user
      @bookmarkable_user ||= chat_message.user
    end

    def bookmarkable_url
      chat_message.url
    end

    def excerpt
      return nil unless cooked
      @excerpt ||= PrettyText.excerpt(cooked, 300, keep_emoji_images: true)
    end

    private

    def chat_message
      object.bookmarkable
    end
  end
end
