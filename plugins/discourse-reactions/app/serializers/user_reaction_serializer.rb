# frozen_string_literal: true
class UserReactionSerializer < ApplicationSerializer
  attributes :id, :user_id, :post_id, :created_at

  has_one :user, serializer: GroupPostUserSerializer, embed: :object
  has_one :post, serializer: GroupPostSerializer, embed: :object
  has_one :reaction, serializer: ReactionSerializer, embed: :object
end
