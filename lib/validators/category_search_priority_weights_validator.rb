# frozen_string_literal: true

class CategorySearchPriorityWeightsValidator
  def initialize(opts = {})
    @name = opts[:name].to_s
  end

  def valid_value?(val)
    val = val.to_f

    case @name
    when "category_search_priority_very_low_weight"
      val < SiteSetting.category_search_priority_low_weight
    when "category_search_priority_low_weight"
      val < 1 && val > SiteSetting.category_search_priority_very_low_weight
    when "category_search_priority_high_weight"
      val > 1 && val < SiteSetting.category_search_priority_very_high_weight
    when "category_search_priority_very_high_weight"
      val > SiteSetting.category_search_priority_high_weight
    end
  end

  def error_message
    key = @name[/category_search_priority_(\w+)_weight/, 1]
    I18n.t("site_settings.errors.category_search_priority.#{key}_weight_invalid")
  end
end
