# frozen_string_literal: true

class AllowUncategorizedTopicsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    val == "f" || Category.exists?(SiteSetting.uncategorized_category_id)
  end

  def error_message
    I18n.t("site_settings.errors.uncategorized_category_missing")
  end
end
