# frozen_string_literal: true

module Chat
  class UserChatChannelMembership < ActiveRecord::Base
    self.table_name = "user_chat_channel_memberships"
    self.ignored_columns = %w[desktop_notification_level mobile_notification_level] # TODO: Remove once 20241003122030_add_notification_level_to_user_chat_channel_memberships has been promoted to pre-deploy

    NOTIFICATION_LEVELS = { never: 0, mention: 1, always: 2 }

    belongs_to :user
    belongs_to :last_read_message, class_name: "Chat::Message", optional: true
    belongs_to :chat_channel, class_name: "Chat::Channel", foreign_key: :chat_channel_id

    enum :notification_level, NOTIFICATION_LEVELS, prefix: :notifications
    enum :join_mode, { manual: 0, automatic: 1 }

    def mark_read!(new_last_read_id = nil)
      update!(last_read_message_id: new_last_read_id || chat_channel.last_message_id)
    end
  end
end

# == Schema Information
#
# Table name: user_chat_channel_memberships
#
#  id                                  :bigint           not null, primary key
#  user_id                             :integer          not null
#  chat_channel_id                     :integer          not null
#  last_read_message_id                :integer
#  following                           :boolean          default(FALSE), not null
#  muted                               :boolean          default(FALSE), not null
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  last_unread_mention_when_emailed_id :integer
#  join_mode                           :integer          default("manual"), not null
#  last_viewed_at                      :datetime         not null
#  notification_level                  :integer          default("mention"), not null
#
# Indexes
#
#  user_chat_channel_memberships_index   (user_id,chat_channel_id,notification_level,following)
#  user_chat_channel_unique_memberships  (user_id,chat_channel_id) UNIQUE
#
