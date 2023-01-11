# frozen_string_literal: true

class AdminChatIndexSerializer < ApplicationSerializer
  has_many :chat_channels, serializer: ChatChannelSerializer, embed: :objects
  has_many :incoming_chat_webhooks, serializer: IncomingChatWebhookSerializer, embed: :objects

  def chat_channels
    object[:chat_channels]
  end

  def incoming_chat_webhooks
    object[:incoming_chat_webhooks]
  end
end
