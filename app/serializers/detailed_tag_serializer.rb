# frozen_string_literal: true

class DetailedTagSerializer < TagSerializer
  attributes :synonyms, :tag_group_names, :category_restricted

  has_many :categories, serializer: BasicCategorySerializer

  def synonyms
    TagsController.tag_counts_json(DiscourseTagging.filter_visible(object.synonyms, scope), scope)
  end

  def categories
    object.all_categories(scope)
  end

  def name
    restricted_from_scope? ? object.name : super
  end

  def category_restricted
    object.all_category_ids.present?
  end

  def include_description?
    !restricted_from_scope?
  end

  def include_description_cooked?
    !restricted_from_scope?
  end

  def include_tag_group_names?
    scope.is_admin? || SiteSetting.tags_listed_by_group == true
  end

  def tag_group_names
    TagGroup
      .visible(scope)
      .where(id: object.tag_group_memberships.select(:tag_group_id))
      .pluck(:name)
  end

  private

  def restricted_from_scope?
    return @restricted_from_scope if defined?(@restricted_from_scope)
    @restricted_from_scope = !object.visible_in_accessible_categories?(scope)
  end
end
