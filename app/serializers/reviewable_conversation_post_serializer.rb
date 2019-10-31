# frozen_string_literal: true

class ReviewableConversationPostSerializer < ApplicationSerializer
  attributes :id, :excerpt
  has_one :user, serializer: BasicUserSerializer, root: 'users'
end
