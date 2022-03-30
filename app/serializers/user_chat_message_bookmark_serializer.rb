# frozen_string_literal: true

class UserChatMessageBookmarkSerializer < UserBookmarkBaseSerializer
  attr_reader :chat_message

  def initialize(obj, chat_message, opts)
    # what is scope??? baby don't hurt me
    super(obj, opts)
    @chat_message = chat_message
  end

  def title
    # this will just be chat_message.chat_channel.name, this will never be nil
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
    "#{Discourse.base_url}/chat/channel/#{chat_message.chat_channel.id}/chat?messageId=#{chat_message.id}"
  end
end
