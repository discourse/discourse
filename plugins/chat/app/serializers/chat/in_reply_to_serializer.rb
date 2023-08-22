# frozen_string_literal: true

module Chat
  class InReplyToSerializer < ApplicationSerializer
    has_one :user, serializer: BasicUserSerializer, embed: :objects
    has_one :chat_webhook_event, serializer: Chat::WebhookEventSerializer, embed: :objects

    attributes :id, :cooked, :excerpt

    def excerpt
      object.censored_excerpt
    end

    def user
      object.user || Chat::DeletedUser.new
    end
  end
end
