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
             :archetype,
             :rank_details,
             :excerpt

  has_one :category
  has_many :posters, serializer: TopicPosterSerializer, embed: :objects

  def starred
    object.user_data.starred?
  end
  alias :include_starred? :seen


  # This is for debugging / tweaking the hot topic rankings.
  # We will likely remove it after we are happier with things.
  def rank_details

    hot_topic_type = case object.hot_topic.hot_topic_type
      when 1 then 'sticky'
      when 2 then 'recent high scoring'
      when 3 then 'old high scoring'
    end

    {topic_score: object.score,
     percent_rank: object.percent_rank,
     random_bias: object.hot_topic.random_bias,
     random_multiplier: object.hot_topic.random_multiplier,
     days_ago_bias: object.hot_topic.days_ago_bias,
     days_ago_multiplier: object.hot_topic.days_ago_multiplier,
     ranking_score: object.hot_topic.score,
     hot_topic_type: hot_topic_type}
  end

  def include_rank_details?
    object.topic_list.try(:has_rank_details?)
  end

  def posters
    object.posters || []
  end

  def pinned
    PinnedCheck.new(object, object.user_data).pinned?
  end

  def include_excerpt?
    pinned
  end

  def excerpt
    object.posts.first.try(:excerpt,220, strip_links: true) || nil
  end

end
