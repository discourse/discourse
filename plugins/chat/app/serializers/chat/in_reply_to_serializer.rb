# frozen_string_literal: true

module Chat
  class InReplyToSerializer < ApplicationSerializer
    has_one :user, serializer: BasicUserSerializer, embed: :objects
    has_one :chat_webhook_event, serializer: Chat::WebhookEventSerializer, embed: :objects

    attributes :id, :cooked, :excerpt

    def user
      object.user || Chat::NullUser.new
    end

    def excerpt
      object.excerpt || object.build_excerpt
    end
  end
end
