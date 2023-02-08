# frozen_string_literal: true

class ChatThreadOriginalMessageSerializer < ApplicationSerializer
  attributes :id, :created_at, :excerpt, :thread_id

  has_one :chat_webhook_event, serializer: ChatWebhookEventSerializer, embed: :objects

  def excerpt
    WordWatcher.censor(object.excerpt)
  end
end
