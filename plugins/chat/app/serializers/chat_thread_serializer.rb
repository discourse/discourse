# frozen_string_literal: true

class ChatThreadSerializer < ApplicationSerializer
  has_one :original_message_user, serializer: BasicUserSerializer, embed: :objects

  attributes :id, :title, :status, :original_message_id, :original_message_excerpt, :created_at

  def original_message_excerpt
    object.original_message.excerpt
  end
end
