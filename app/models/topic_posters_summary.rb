class TopicPostersSummary
  attr_reader :topic, :options

  def initialize(topic, options = {})
    @topic = topic
    @options = options
  end

  def summary
    sorted_top_posters.compact.map(&method(:new_topic_poster_for))
  end

  private

  def new_topic_poster_for(user)
    TopicPoster.new.tap do |topic_poster|
      topic_poster.user = user
      topic_poster.description = descriptions_for(user)
      if topic.last_post_user_id == user.id
        topic_poster.extras = 'latest'
        topic_poster.extras << ' single' if user_ids.uniq.size == 1
      end
    end
  end

  def descriptions_by_id
    @descriptions_by_id ||= begin
      user_ids_with_descriptions.each_with_object({}) do |(id, description), descriptions|
        descriptions[id] ||= []
        descriptions[id] << description
      end
    end
  end

  def descriptions_for(user)
    descriptions_by_id[user.id].join ', '
  end

  def shuffle_last_poster_to_back_in(summary)
    unless last_poster_is_topic_creator?
      summary.reject!{ |u| u.id == topic.last_post_user_id }
      summary << avatar_lookup[topic.last_post_user_id]
    end
    summary
  end

  def user_ids_with_descriptions
    user_ids.zip([
      :original_poster,
      :most_recent_poster,
      :frequent_poster,
      :frequent_poster,
      :frequent_poster,
      :frequent_poster
      ].map { |description| I18n.t(description) })
  end

  def last_poster_is_topic_creator?
    topic.user_id == topic.last_post_user_id
  end

  def sorted_top_posters
    shuffle_last_poster_to_back_in top_posters
  end

  def top_posters
    user_ids.map { |id| avatar_lookup[id] }.compact.uniq.take(5)
  end

  def user_ids
    [ topic.user_id, topic.last_post_user_id, *topic.featured_user_ids ]
  end

  def avatar_lookup
    @avatar_lookup ||= options[:avatar_lookup] || AvatarLookup.new(user_ids)
  end
end
