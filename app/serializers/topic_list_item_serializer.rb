require_dependency 'pinned_check'

class TopicListItemSerializer < ListableTopicSerializer

  attributes :views,
             :like_count,
             :visible,
             :pinned,
             :closed,
             :archived,
             :starred,
             :has_best_of,
             :archetype

  has_one :category
  has_many :posters, serializer: TopicPosterSerializer, embed: :objects

  def starred
    object.user_data.starred?
  end
  alias :include_starred? :seen

  def posters
    object.posters || []
  end

  def pinned
    PinnedCheck.new(object, object.user_data).pinned?
  end

end
