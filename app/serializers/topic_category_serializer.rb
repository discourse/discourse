# frozen_string_literal: true

class TopicCategorySerializer < ApplicationSerializer
  attributes :id,
             :name,
             :color,
             :text_color,
             :slug,
             :description_text,
             :read_restricted,
             :parent_category_id

  def include_parent_category_id?
    parent_category_id
  end

  def name
    if object.uncategorized?
      I18n.t("uncategorized_category_name", locale: SiteSetting.default_locale)
    else
      object.name
    end
  end

  def description_text
    if object.uncategorized?
      I18n.t("category.uncategorized_description", locale: SiteSetting.default_locale)
    else
      object.description_text
    end
  end
end
