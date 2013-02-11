require_dependency 'excerpt_type'

class CategoryExcerptSerializer < ActiveModel::Serializer
  include ExcerptType

  attributes :excerpt, :name, :color, :slug, :topic_url, :topics_year,
             :topics_month, :topics_week, :category_url, :can_edit, :can_delete


  def topics_year
    object.topics_year || 0
  end

  def topics_month
    object.topics_month || 0
  end

  def topics_week
    object.topics_week || 0
  end

  def category_url
    "/category/#{object.slug}"
  end

  def can_edit
    scope.can_edit?(object)
  end

  def can_delete
    scope.can_delete?(object)
  end

end
