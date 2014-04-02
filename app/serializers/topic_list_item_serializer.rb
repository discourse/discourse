class TopicListItemSerializer < ListableTopicSerializer

  attributes :views,
             :like_count,
             :starred,
             :has_summary,
             :archetype,
             :last_poster_username,
             :category_id

  has_many :posters, serializer: TopicPosterSerializer, embed: :objects, include: true

  def starred
    object.user_data.starred?
  end

  def posters
    object.posters || []
  end

  def last_poster_username
    object.posters.find { |poster| poster.user.id == object.last_post_user_id }.try(:user).try(:username)
  end

  def filter(keys)
    keys.delete(:starred) unless object.user_data
    super(keys)
  end

end
