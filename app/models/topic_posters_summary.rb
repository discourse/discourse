# frozen_string_literal: true

# This is used in topic lists
class TopicPostersSummary

  # localization is fast, but this allows us to avoid
  # calling it in a loop which adds up
  def self.translations
    {
      original_poster: I18n.t(:original_poster),
      most_recent_poster: I18n.t(:most_recent_poster),
      frequent_poster: I18n.t(:frequent_poster)
    }
  end

  attr_reader :topic, :options

  def initialize(topic, options = {})
    @topic = topic
    @options = options
    @translations = options[:translations] || TopicPostersSummary.translations
  end

  def summary
    sorted_top_posters.compact.map(&method(:new_topic_poster_for))
  end

  private

  def new_topic_poster_for(user)
    topic_poster = TopicPoster.new
    topic_poster.user = user
    topic_poster.description = descriptions_for(user)
    topic_poster.primary_group = primary_group_lookup[user.id]
    if topic.last_post_user_id == user.id
      topic_poster.extras = +'latest'
      topic_poster.extras << ' single' if user_ids.uniq.size == 1
    end
    topic_poster
  end

  def descriptions_by_id
    @descriptions_by_id ||= begin
      result = {}
      ids = user_ids

      if id = ids.shift
        result[id] ||= []
        result[id] << @translations[:original_poster]
      end

      if id = ids.shift
        result[id] ||= []
        result[id] << @translations[:most_recent_poster]
      end

      while id = ids.shift
        result[id] ||= []
        result[id] << @translations[:frequent_poster]
      end

      result
    end
  end

  def descriptions_for(user)
    descriptions_by_id[user.id].join ', '
  end

  def shuffle_last_poster_to_back_in(summary)
    unless last_poster_is_topic_creator?
      summary.reject! { |u| u.id == topic.last_post_user_id }
      summary << avatar_lookup[topic.last_post_user_id]
    end
    summary
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

  def primary_group_lookup
    @primary_group_lookup ||= options[:primary_group_lookup] || PrimaryGroupLookup.new(user_ids)
  end
end
