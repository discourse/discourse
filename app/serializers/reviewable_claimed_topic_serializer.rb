# frozen_string_literal: true

class ReviewableClaimedTopicSerializer < ApplicationSerializer
  attributes(:id, :automatic)

  has_one :user, serializer: UserWithCustomFieldsSerializer, root: "users"
end
