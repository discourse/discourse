# frozen_string_literal: true

class ChatThreadSerializer < ApplicationSerializer
  has_one :original_message_user, serializer: BasicUserWithStatusSerializer, embed: :objects
  has_one :original_message, serializer: ChatThreadOriginalMessageSerializer, embed: :objects

  attributes :id, :title, :status
end
