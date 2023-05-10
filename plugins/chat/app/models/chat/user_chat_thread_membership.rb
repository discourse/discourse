# frozen_string_literal: true

module Chat
  class UserChatThreadMembership < ActiveRecord::Base
    self.table_name = "user_chat_thread_memberships"

    belongs_to :user
    belongs_to :last_read_message, class_name: "Chat::Message", optional: true
    belongs_to :thread, class_name: "Chat::Thread", foreign_key: :thread_id

    enum :notification_level, NotificationLevels.chat_levels
  end
end

# == Schema Information
#
# Table name: user_chat_thread_memberships
#
#  id                   :bigint           not null, primary key
#  user_id              :bigint           not null
#  thread_id            :bigint           not null
#  last_read_message_id :bigint
#  notification_level   :integer          default(2), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
