# frozen_string_literal: true

module Chat
  class Thread < ActiveRecord::Base
    EXCERPT_LENGTH = 150

    self.table_name = "chat_threads"

    belongs_to :channel, foreign_key: "channel_id", class_name: "Chat::Channel"
    belongs_to :original_message_user, foreign_key: "original_message_user_id", class_name: "User"
    belongs_to :original_message, foreign_key: "original_message_id", class_name: "Chat::Message"

    has_many :chat_messages,
             -> { order("chat_messages.created_at ASC, chat_messages.id ASC") },
             foreign_key: :thread_id,
             primary_key: :id,
             class_name: "Chat::Message"

    enum :status, { open: 0, read_only: 1, closed: 2, archived: 3 }, scopes: false

    def url
      "#{channel.url}/t/#{self.id}"
    end

    def relative_url
      "#{channel.relative_url}/t/#{self.id}"
    end

    def excerpt
      original_message.excerpt(max_length: EXCERPT_LENGTH)
    end
  end
end

# == Schema Information
#
# Table name: chat_threads
#
#  id                       :bigint           not null, primary key
#  channel_id               :integer          not null
#  original_message_id      :integer          not null
#  original_message_user_id :integer          not null
#  status                   :integer          default("open"), not null
#  title                    :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_chat_threads_on_channel_id                (channel_id)
#  index_chat_threads_on_channel_id_and_status     (channel_id,status)
#  index_chat_threads_on_original_message_id       (original_message_id)
#  index_chat_threads_on_original_message_user_id  (original_message_user_id)
#  index_chat_threads_on_status                    (status)
#
