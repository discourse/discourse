# frozen_string_literal: true

class ChatInReplyToSerializer < ApplicationSerializer
  has_one :user, serializer: BasicUserSerializer, embed: :objects
  has_one :chat_webhook_event, serializer: ChatWebhookEventSerializer, embed: :objects

  attributes :id, :cooked, :excerpt

  def excerpt
    WordWatcher.censor(object.excerpt)
  end

  def user
    object.user || DeletedChatUser.new
  end
end
