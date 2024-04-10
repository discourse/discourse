# frozen_string_literal: true

module Chat
  class Mention < ActiveRecord::Base
    self.table_name = "chat_mentions"
    self.ignored_columns = %w[notification_id user_id]

    belongs_to :chat_message, class_name: "Chat::Message"
    has_many :mention_notifications,
             class_name: "Chat::MentionNotification",
             foreign_key: :chat_mention_id
    has_many :notifications, through: :mention_notifications, dependent: :destroy
  end
end

# == Schema Information
#
# Table name: chat_mentions
#
#  id              :bigint           not null, primary key
#  chat_message_id :integer          not null
#  target_id       :integer
#  type            :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
# index_chat_mentions_on_chat_message_id    (chat_message_id)
# index_chat_mentions_on_target_id          (target_id)
#
