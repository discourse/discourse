# frozen_string_literal: true

class ReviewableConversationSerializer < ApplicationSerializer
  attributes :id, :permalink, :has_more
  has_many :conversation_posts, serializer: ReviewableConversationPostSerializer
end
