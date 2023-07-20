# frozen_string_literal: true

module Chat
  class IncomingWebhookSerializer < ApplicationSerializer
    has_one :chat_channel, serializer: Chat::ChannelSerializer, embed: :objects

    attributes :id, :name, :description, :emoji, :url, :username, :updated_at
  end
end
