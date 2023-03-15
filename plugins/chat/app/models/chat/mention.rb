# frozen_string_literal: true

module Chat
  class Mention < ActiveRecord::Base
    self.table_name = "chat_mentions"

    belongs_to :user
    belongs_to :chat_message, class_name: "Chat::Message"
    belongs_to :notification, dependent: :destroy
  end
end

# == Schema Information
#
# Table name: chat_mentions
#
#  id              :bigint           not null, primary key
#  chat_message_id :integer          not null
#  user_id         :integer          not null
#  notification_id :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  chat_mentions_index  (chat_message_id,user_id,notification_id) UNIQUE
#
