# frozen_string_literal: true
class WebHookLikeSerializer < ApplicationSerializer
  has_one :post, serializer: WebHookPostSerializer, embed: :objects
  has_one :user, serializer: BasicUserSerializer, embed: :objects
end
