# frozen_string_literal: true

module Chat
  class PinnedMessage < ActiveRecord::Base
    self.table_name = "chat_pinned_messages"

    MAX_PINS_PER_CHANNEL = 20

    belongs_to :chat_message, class_name: "Chat::Message"
    belongs_to :chat_channel, class_name: "Chat::Channel"
    belongs_to :user, foreign_key: :pinned_by_id

    validates :chat_message_id, uniqueness: true

    scope :for_channel, ->(channel) { where(chat_channel: channel).order(created_at: :desc) }
  end
end
