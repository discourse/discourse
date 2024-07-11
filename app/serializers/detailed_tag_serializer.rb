# frozen_string_literal: true

class DetailedTagSerializer < TagSerializer
  attributes :synonyms, :tag_group_names, :category_restricted

  has_many :categories, serializer: BasicCategorySerializer

  def synonyms
    TagsController.tag_counts_json(object.synonyms, scope)
  end

  def categories
    object.all_categories(scope)
  end

  def category_restricted
    object.all_category_ids.present?
  end

  def include_tag_group_names?
    scope.is_admin? || SiteSetting.tags_listed_by_group == true
  end

  def tag_group_names
    object.tag_groups.map(&:name)
  end
end
