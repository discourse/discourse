class SuggestedTopicSerializer < ListableTopicSerializer

  # need to embed so we have users
  # front page json gets away without embedding
  class SuggestedPosterSerializer < ApplicationSerializer
    attributes :extras, :description
    has_one :user, serializer: BasicUserSerializer, embed: :objects
  end

  attributes :archetype, :like_count, :views, :category_id
  has_many :posters, serializer: SuggestedPosterSerializer, embed: :objects

  def include_posters?
    object.private_message?
  end

  def posters
    object.posters || []
  end
end
