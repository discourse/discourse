# frozen_string_literal: true

class SiteCategorySerializer < BasicCategorySerializer
  attributes :allowed_tags,
             :allowed_tag_groups,
             :allow_global_tags,
             :read_only_banner,
             :form_template_ids

  has_many :category_required_tag_groups, key: :required_tag_groups, embed: :objects

  def form_template_ids
    object.form_template_ids.sort
  end

  def include_allowed_tags?
    SiteSetting.tagging_enabled
  end

  def allowed_tags
    object.tags.pluck(:name)
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
end
