class TopicPosterSerializer < ApplicationSerializer
  attributes :extras, :description
  has_one :user, serializer: BasicUserSerializer
  has_one :primary_group, serializer: PrimaryGroupSerializer
end
