class CategoryDetailedSerializer < BasicCategorySerializer

  attributes :post_count,
             :topics_week,
             :topics_month,
             :topics_year,
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

  def is_uncategorized
    object.id == SiteSetting.uncategorized_category_id
  end

  def include_is_uncategorized?
    is_uncategorized
  end

  def include_displayable_topics?
    return displayable_topics.present?
  end

  def description_excerpt
    PrettyText.excerpt(description,300) if description
  end

  def include_subcategory_ids?
    subcategory_ids.present?
  end

end
