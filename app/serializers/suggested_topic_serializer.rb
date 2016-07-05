class SuggestedTopicSerializer < ListableTopicSerializer

  # need to embed so we have users
  # front page json gets away without embedding
  class SuggestedPosterSerializer < ApplicationSerializer
    attributes :extras, :description
    has_one :user, serializer: BasicUserSerializer, embed: :objects
  end

  attributes :archetype, :like_count, :views, :category_id, :tags
  has_many :posters, serializer: SuggestedPosterSerializer, embed: :objects

  def posters
    object.posters || []
  end

  def include_tags?
    SiteSetting.tagging_enabled
  end

  def tags
    object.tags.map(&:name)
  end
end
