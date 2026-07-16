# frozen_string_literal: true

class SiteCategorySerializer < BasicCategorySerializer
  attributes :allowed_tags,
             :allowed_tag_groups,
             :allow_global_tags,
             :read_only_banner,
             :form_template_ids,
             :category_types

  has_many :category_required_tag_groups, key: :required_tag_groups, embed: :objects

  def form_template_ids
    object.form_template_ids.sort
  end

  def category_types
    return {} if !SiteSetting.enable_simplified_category_creation
    object.category_types
  end

  def include_allowed_tags?
    SiteSetting.tagging_enabled
  end

  def allowed_tags
    object.tags.pluck(:id, :name, :slug).map { |id, name, slug| { id: id, name: name, slug: slug } }
  end

  def include_allowed_tag_groups?
    SiteSetting.tagging_enabled
  end

  def allowed_tag_groups
    object.tag_groups.pluck(:name)
  end

  def include_allow_global_tags?
    SiteSetting.tagging_enabled
  end

  def include_required_tag_groups?
    SiteSetting.tagging_enabled
  end

  def name
    return I18n.t("uncategorized_category_name") if object.uncategorized?

    localization&.name.presence || object.name
  end

  def description
    localized_description || object.description
  end

  def description_text
    return super if object.uncategorized?
    return localization.description_text if localized_description
    object.description_text
  end

  def description_excerpt
    return super if object.uncategorized?
    return localization.description_excerpt if localized_description
    object.description_excerpt
  end

  private

  def localization
    return @localization if defined?(@localization)
    @localization =
      (object.get_localization if ContentLocalization.show_translated_category?(object, scope))
  end

  def localized_description
    return @localized_description if defined?(@localized_description)
    @localized_description = localization&.description_first_paragraph.presence
  end
end
