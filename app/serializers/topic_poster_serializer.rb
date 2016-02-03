class TopicPosterSerializer < ApplicationSerializer
  attributes :extras, :description
  has_one :user, serializer: BasicUserSerializer
end
