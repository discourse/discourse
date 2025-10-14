# frozen_string_literal: true

class CategoryBadgeSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :slug,
             :color,
             :text_color,
             :style_type,
             :icon,
             :emoji,
             :read_restricted,
             :parent_category_id

  def include_parent_category_id?
    parent_category_id.present?
  end

  def name
    return I18n.t("uncategorized_category_name") if object.uncategorized?

    translated =
      if (ContentLocalization.show_translated_category?(object, scope))
        object.get_localization&.name
      else
        object.name
      end

    translated || object.name
  end

  def description_text
    if object.uncategorized?
      I18n.t("category.uncategorized_description", locale: SiteSetting.default_locale)
    else
      object.description_text
    end
  end
end
