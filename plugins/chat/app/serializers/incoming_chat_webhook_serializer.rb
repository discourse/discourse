# frozen_string_literal: true

class IncomingChatWebhookSerializer < ApplicationSerializer
  has_one :chat_channel, serializer: ChatChannelSerializer, embed: :objects

  attributes :id, :name, :description, :emoji, :url, :username, :updated_at
end
