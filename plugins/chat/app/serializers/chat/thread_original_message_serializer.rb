# frozen_string_literal: true

module Chat
  class ThreadOriginalMessageSerializer < ApplicationSerializer
    attributes :id, :created_at, :excerpt, :thread_id

    has_one :chat_webhook_event, serializer: Chat::WebhookEventSerializer, embed: :objects

    def excerpt
      WordWatcher.censor(object.rich_excerpt(max_length: Chat::Thread::EXCERPT_LENGTH))
    end
  end
end
