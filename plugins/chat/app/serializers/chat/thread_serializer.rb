# frozen_string_literal: true

module Chat
  class ThreadSerializer < ApplicationSerializer
    has_one :original_message_user, serializer: BasicUserWithStatusSerializer, embed: :objects
    has_one :original_message, serializer: Chat::ThreadOriginalMessageSerializer, embed: :objects

    attributes :id, :title, :status, :channel_id
  end
end
