# frozen_string_literal: true

class DetailedTagSerializer < TagSerializer
  attributes :synonyms, :tag_group_names

  has_many :categories, serializer: BasicCategorySerializer

  def synonyms
    TagsController.tag_counts_json(object.synonyms)
  end

  def categories
    Category.secured(scope).where(
      id: object.categories.pluck(:id) +
        object.tag_groups.includes(:categories).map do |tg|
          tg.categories.map(&:id)
        end.flatten
    )
  end

  def include_tag_group_names?
    scope.is_admin? || SiteSetting.tags_listed_by_group == true
  end

  def tag_group_names
    object.tag_groups.map(&:name)
  end
end
