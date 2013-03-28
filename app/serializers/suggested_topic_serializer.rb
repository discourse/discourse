class SuggestedTopicSerializer < ListableTopicSerializer

  attributes :archetype, :like_count, :views
  has_one :category, embed: :objects

end
