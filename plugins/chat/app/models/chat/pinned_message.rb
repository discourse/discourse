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

# == Schema Information
#
# Table name: chat_pinned_messages
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  chat_channel_id :bigint           not null
#  chat_message_id :bigint           not null
#  pinned_by_id    :bigint           not null
#
# Indexes
#
#  idx_chat_pinned_messages_channel_created       (chat_channel_id,created_at DESC)
#  index_chat_pinned_messages_on_chat_message_id  (chat_message_id) UNIQUE
#
