# frozen_string_literal: true

module Chat
  class WebhookEvent < ActiveRecord::Base
    self.table_name = "chat_webhook_events"

    belongs_to :chat_message, class_name: "Chat::Message"
    belongs_to :incoming_chat_webhook, class_name: "Chat::IncomingWebhook"

    delegate :username, to: :incoming_chat_webhook
    delegate :emoji, to: :incoming_chat_webhook
  end
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
