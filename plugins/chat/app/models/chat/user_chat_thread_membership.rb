# frozen_string_literal: true

module Chat
  class UserChatThreadMembership < ActiveRecord::Base
    self.table_name = "user_chat_thread_memberships"

    belongs_to :user
    belongs_to :last_read_message, class_name: "Chat::Message", optional: true
    belongs_to :thread, class_name: "Chat::Thread", foreign_key: :thread_id

    enum :notification_level, Chat::NotificationLevels.all

    def mark_read!(new_last_read_id = nil)
      update!(last_read_message_id: new_last_read_id || thread.last_message_id)
    end
  end
end

# == Schema Information
#
# Table name: user_chat_thread_memberships
#
#  id                        :bigint           not null, primary key
#  user_id                   :bigint           not null
#  thread_id                 :bigint           not null
#  last_read_message_id      :bigint
#  notification_level        :integer          default("tracking"), not null
#  thread_title_prompt_seen  :boolean          default(false), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  user_chat_thread_unique_memberships  (user_id,thread_id) UNIQUE
#
