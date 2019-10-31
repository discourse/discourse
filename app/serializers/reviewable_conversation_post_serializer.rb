# frozen_string_literal: true

class ReviewableConversationPostSerializer < ApplicationSerializer
  root 'reviewable_conversation_post'

  attributes :id, :excerpt
  has_one :user, serializer: BasicUserSerializer, root: 'users'
end
