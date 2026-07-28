# frozen_string_literal: true

class SiteCategorySerializer < BasicCategorySerializer
  attributes :allow_global_tags, :read_only_banner, :form_template_ids, :required_tag_groups

  def form_template_ids
    object.form_template_ids.sort
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

    translated_name =
      if (ContentLocalization.show_translated_category?(object, scope))
        object.get_localization&.name
      else
        object.name
      end

    translated_name || object.name
  end

  def description
    translated_description =
      if (ContentLocalization.show_translated_category?(object, scope))
        object.get_localization&.description
      else
        object.description
      end

    translated_description || object.description
  end

  private

  def can_edit_tags?
    return @can_edit_tags if defined?(@can_edit_tags)
    @can_edit_tags = SiteSetting.tagging_enabled && scope&.can_edit?(object)
  end
end
