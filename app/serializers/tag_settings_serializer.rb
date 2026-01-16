# frozen_string_literal: true

class TagSettingsSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :slug,
             :description,
             :synonyms,
             :tag_group_names,
             :tag_groups,
             :category_restricted,
             :can_edit,
             :can_admin

  has_many :categories, serializer: BasicCategorySerializer
  has_many :localizations, serializer: TagLocalizationSerializer, embed: :objects

  # return raw name, not localized, for editing
  def name
    object.name
  end

  def description
    object.description
  end

  def synonyms
    TagsController.tag_counts_json(object.synonyms, scope)
  end

  def categories
    object.all_categories(scope)
  end

  def category_restricted
    object.all_category_ids.present?
  end

  def tag_group_names
    object.tag_groups.map(&:name)
  end

  def tag_groups
    object.tag_groups.map { |tg| { id: tg.id, name: tg.name } }
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
end
