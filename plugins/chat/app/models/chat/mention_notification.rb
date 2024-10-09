# frozen_string_literal: true

module Chat
  class MentionNotification < ActiveRecord::Base
    # TODO(2025-01-15): Remove ignored_columns
    self.ignored_columns = [:old_notification_id]

    self.table_name = "chat_mention_notifications"

    belongs_to :chat_mention, class_name: "Chat::Mention"
    belongs_to :notification, dependent: :destroy
  end
end

# == Schema Information
#
# Table name: chat_mention_notifications
#
#  chat_mention_id :integer          not null
#  notification_id :bigint           not null
#
# Indexes
#
#  index_chat_mention_notifications_on_chat_mention_id  (chat_mention_id)
#  index_chat_mention_notifications_on_notification_id  (notification_id) UNIQUE
#
