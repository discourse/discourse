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

      # Rules are a lot looser for DMs between 2 people, allows for
      # things like "ok", "yes", "no", "lol", "haha", "tee-hee"
      # to be sent multiple times.
      return if chat_channel.direct_message_channel? && chat_channel.user_count <= 2

      # It's not possible to duplicate a message that only contains uploads,
      # since the message is empty.
      return if chat_message.only_uploads?

      recent_identical_message_found =
        chat_channel
          .chat_messages
          .includes(:uploads)
          .where(created_at: 10.seconds.ago..)
          .where("LOWER(message) = ?", chat_message.message.strip.downcase)
          .where(user: chat_message.user)
          .exists?

      if recent_identical_message_found
        chat_message.errors.add(:base, I18n.t("chat.errors.duplicate_message"))
      end
    end
  end
end
