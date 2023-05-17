# frozen_string_literal: true

module Chat
  class UserChatChannelMembership < ActiveRecord::Base
    self.table_name = "user_chat_channel_memberships"

    NOTIFICATION_LEVELS = { never: 0, mention: 1, always: 2 }

    belongs_to :user
    belongs_to :last_read_message, class_name: "Chat::Message", optional: true
    belongs_to :chat_channel, class_name: "Chat::Channel", foreign_key: :chat_channel_id

    enum :desktop_notification_level, NOTIFICATION_LEVELS, prefix: :desktop_notifications
    enum :mobile_notification_level, NOTIFICATION_LEVELS, prefix: :mobile_notifications
    enum :join_mode, { manual: 0, automatic: 1 }
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
#  desktop_notification_level          :integer          default("mention"), not null
#  mobile_notification_level           :integer          default("mention"), not null
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  last_unread_mention_when_emailed_id :integer
#  join_mode                           :integer          default("manual"), not null
#
# Indexes
#
#  user_chat_channel_memberships_index   (user_id,chat_channel_id,desktop_notification_level,mobile_notification_level,following)
#  user_chat_channel_unique_memberships  (user_id,chat_channel_id) UNIQUE
#
