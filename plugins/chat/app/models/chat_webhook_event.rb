# frozen_string_literal: true

class ChatWebhookEvent < ActiveRecord::Base
  belongs_to :chat_message
  belongs_to :incoming_chat_webhook

  delegate :username, to: :incoming_chat_webhook
  delegate :emoji, to: :incoming_chat_webhook
end

# == Schema Information
#
# Table name: chat_webhook_events
#
#  id                       :bigint           not null, primary key
#  chat_message_id          :integer          not null
#  incoming_chat_webhook_id :integer          not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  chat_webhook_events_index  (chat_message_id,incoming_chat_webhook_id) UNIQUE
#
