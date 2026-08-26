# frozen_string_literal: true

module Chat
  class MessageHashtagStore < HashtagRemapper::Store
    def self.key = "chat_message"
    def self.relation = Chat::Message.where(deleted_at: nil)
    def self.raw_column = :message
    def self.cooked(message) = message.cooked
    def self.hashtag_context = "chat-composer"
    def self.cook_options(message) = Chat::Message.markdown_options(user_id: message.last_editor_id)

    def self.write!(message, raw)
      message.message = raw
      message.cook
      message.excerpt = message.build_excerpt
      message.save!(validate: false)
      message.rebake!(skip_notifications: true, priority: :ultra_low)
      SearchIndexer.index(message)
    end
  end
end
