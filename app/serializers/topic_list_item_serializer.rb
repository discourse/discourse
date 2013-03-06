require_dependency 'pinned_check'

class TopicListItemSerializer < BasicTopicSerializer

  attributes :views,
             :like_count,
             :visible,
             :pinned,
             :closed,
             :archived,
             :last_post_age,
             :starred,
             :has_best_of,
             :archetype,
             :slug

  has_one :category
  has_many :posters, serializer: TopicPosterSerializer, embed: :objects

  def last_post_age
    return nil if object.last_posted_at.blank?
    AgeWords.age_words(Time.now - object.last_posted_at)
  end

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
