class CategoryDetailedSerializer < BasicCategorySerializer

  attributes :topic_count,
             :post_count,
             :topics_day,
             :topics_week,
             :topics_month,
             :topics_year,
             :posts_day,
             :posts_week,
             :posts_month,
             :posts_year,
             :description_excerpt,
             :is_uncategorized,
             :subcategory_ids

  has_many :featured_users, serializer: BasicUserSerializer
  has_many :displayable_topics, serializer: ListableTopicSerializer, embed: :objects, key: :topics


  def topics_week
    object.topics_week || 0
  end

  def topics_month
    object.topics_month || 0
  end

  def topics_year
    object.topics_year || 0
  end

  def posts_week
    object.posts_week || 0
  end

  def posts_month
    object.posts_month || 0
  end

  def posts_year
    object.posts_year || 0
  end

  def filter(keys)
    rejected_keys = []
    rejected_keys << :is_uncategorized unless is_uncategorized
    rejected_keys << :displayable_topics unless displayable_topics.present?
    rejected_keys << :subcategory_ids unless subcategory_ids.present?
    keys - rejected_keys
  end

  def is_uncategorized
    object.id == SiteSetting.uncategorized_category_id
  end

  def description_excerpt
    PrettyText.excerpt(description,300) if description
  end

end
