# frozen_string_literal: true

class ReviewableConversationSerializer < ApplicationSerializer
  root 'reviewable_conversation_serializer'

  attributes :id, :permalink, :has_more
  has_many :conversation_posts, serializer: ReviewableConversationPostSerializer
end
