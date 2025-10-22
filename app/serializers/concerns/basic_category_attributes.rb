# frozen_string_literal: true

module BasicCategoryAttributes
  def category_name
    if object.uncategorized?
      I18n.t("uncategorized_category_name", locale: SiteSetting.default_locale)
    else
      object.name
    end
  end

  def category_description
    if object.uncategorized?
      I18n.t("category.uncategorized_description", locale: SiteSetting.default_locale)
    else
      object.description
    end
  end
end
