# frozen_string_literal: true

module Chat
  class AdminChatWebhookShowSerializer < ApplicationSerializer
    has_many :chat_channels, serializer: Chat::ChannelSerializer, embed: :objects
    has_one :webhook, serializer: Chat::IncomingWebhookSerializer, embed: :objects

    def chat_channels
      object[:chat_channels]
    end

    def webhook
      object[:webhook]
    end
  end
end
