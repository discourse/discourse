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

  def is_uncategorized
    object.id == SiteSetting.uncategorized_category_id
  end

  def include_is_uncategorized?
    is_uncategorized
  end

  def include_displayable_topics?
    displayable_topics.present?
  end

  def description_excerpt
    PrettyText.excerpt(description,300) if description
  end

  def include_subcategory_ids?
    subcategory_ids.present?
  end

  # Topic and post counts, including counts from the sub-categories:

  def topics_day
    count_with_subcategories(:topics_day)
  end

  def topics_week
    count_with_subcategories(:topics_week)
  end

  def topics_month
    count_with_subcategories(:topics_month)
  end

  def topics_year
    count_with_subcategories(:topics_year)
  end

  def posts_day
    count_with_subcategories(:posts_day)
  end

  def posts_week
    count_with_subcategories(:posts_week)
  end

  def posts_month
    count_with_subcategories(:posts_month)
  end

  def posts_year
    count_with_subcategories(:posts_year)
  end

  def count_with_subcategories(method)
    count = object.send(method) || 0
    object.subcategories.each do |category|
      count += (category.send(method) || 0)
    end
    count
  end

end
