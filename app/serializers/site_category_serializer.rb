# frozen_string_literal: true

class SiteCategorySerializer < BasicCategorySerializer
  attributes :allow_global_tags,
             :read_only_banner,
             :form_template_ids,
             :required_tag_groups,
             :category_types

  def form_template_ids
    object.form_template_ids.sort
  end

  def category_types
    return {} if !SiteSetting.enable_simplified_category_creation
    object.category_types
  end

  def include_allow_global_tags?
    SiteSetting.tagging_enabled
  end

  def include_required_tag_groups?
    SiteSetting.tagging_enabled
  end

  def required_tag_groups
    object.category_required_tag_groups.map do |crtg|
      entry = { min_count: crtg.min_count }
      entry[:name] = crtg.tag_group&.name if can_edit_tags?
      entry
    end
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

  def can_edit_tags?
    return @can_edit_tags if defined?(@can_edit_tags)
    @can_edit_tags = SiteSetting.tagging_enabled && scope&.can_edit?(object)
  end

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
