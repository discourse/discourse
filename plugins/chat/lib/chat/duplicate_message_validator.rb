# frozen_string_literal: true

module Chat
  class DuplicateMessageValidator
    attr_reader :chat_message, :chat_channel

    def initialize(chat_message)
      @chat_message = chat_message
      @chat_channel = chat_message&.chat_channel
    end

    def validate
      return if chat_message.nil? || chat_channel.nil?
      return if chat_message.user.bot?
      return if chat_channel.direct_message_channel? && chat_channel.user_count <= 2

      if chat_channel
           .chat_messages
           .where(created_at: 10.seconds.ago..)
           .where("LOWER(message) = ?", chat_message.message.strip.downcase)
           .where(user: chat_message.user)
           .exists?
        chat_message.errors.add(:base, I18n.t("chat.errors.duplicate_message"))
      end
    end
  end
end
