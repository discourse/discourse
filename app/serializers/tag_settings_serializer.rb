# frozen_string_literal: true

class TagSettingsSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :slug,
             :description,
             :description_cooked,
             :synonyms,
             :tag_group_names,
             :tag_groups,
             :category_restricted,
             :can_edit,
             :can_admin

  has_many :categories, serializer: BasicCategorySerializer
  has_many :localizations, serializer: TagLocalizationSerializer, embed: :objects

  def name
    object.name
  end

  def slug
    object.slug_for_url
  end

  def description
    object.description
  end

  def description_cooked
    object.description_cooked
  end

  def synonyms
    visible_synonyms.map { |t| { id: t.id, name: t.name } }
  end

  def categories
    object.all_categories(scope)
  end

  def category_restricted
    object.all_category_ids.present?
  end

  def tag_group_names
    visible_tag_groups.map(&:name)
  end

  def tag_groups
    visible_tag_groups.map { |tg| { id: tg.id, name: tg.name } }
  end

  def can_edit
    scope.can_edit_tag?(object)
  end

  def can_admin
    scope.can_admin_tags?
  end

  def include_tag_group_names?
    scope.is_admin? || SiteSetting.tags_listed_by_group == true
  end

  def include_tag_groups?
    scope.is_admin? || SiteSetting.tags_listed_by_group == true
  end

  def include_localizations?
    SiteSetting.content_localization_enabled
  end

  private

  def visible_synonyms
    @visible_synonyms ||= object.synonyms.select { |tag| scope.can_see_tag?(tag) }
  end

  def visible_tag_groups
    @visible_tag_groups ||=
      begin
        tag_groups = object.tag_groups
        visible_tag_group_ids = TagGroup.visible(scope).where(id: tag_groups.map(&:id)).pluck(:id)
        tag_groups.select { |tag_group| visible_tag_group_ids.include?(tag_group.id) }
      end
  end
end
