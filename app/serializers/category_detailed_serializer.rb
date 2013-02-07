class CategoryDetailedSerializer < CategorySerializer

  attributes :topic_count, :topics_week, :topics_month, :topics_year

  has_many :featured_users, serializer: BasicUserSerializer
  has_many :featured_topics, serializer: CategoryTopicSerializer, embed: :objects, key: :topics

  def topics_week
    object.topics_week || 0
  end

  def topics_month
    object.topics_month || 0
  end

  def topics_year
    object.topics_year || 0
  end

end
