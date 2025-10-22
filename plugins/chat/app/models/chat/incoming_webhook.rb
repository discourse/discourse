# frozen_string_literal: true

module Chat
  class IncomingWebhook < ActiveRecord::Base
    self.table_name = "incoming_chat_webhooks"

    belongs_to :chat_channel, class_name: "Chat::Channel"
    has_many :chat_webhook_events,
             foreign_key: "incoming_chat_webhook_id",
             class_name: "Chat::WebhookEvent",
             dependent: :delete_all

    before_create { self.key = SecureRandom.hex(12) }

    validates :name, presence: true, length: { maximum: 100 }
    validates :key, length: { maximum: 100 }
    validates :username, length: { maximum: 100 }
    validates :description, length: { maximum: 500 }
    validates :emoji, length: { maximum: 100 }

    def url
      "#{Discourse.base_url}/chat/hooks/#{key}"
    end
  end
end

# == Schema Information
#
# Table name: incoming_chat_webhooks
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  key             :string           not null
#  chat_channel_id :bigint           not null
#  username        :string
#  description     :string
#  emoji           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_incoming_chat_webhooks_on_key_and_chat_channel_id  (key,chat_channel_id)
#
