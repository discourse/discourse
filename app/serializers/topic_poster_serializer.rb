class TopicPosterSerializer < ApplicationSerializer

  attributes :extras, :description
  has_one :user, serializer: BasicUserSerializer, embed_in_root: true

end
