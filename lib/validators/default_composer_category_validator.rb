# frozen_string_literal: true

class DefaultComposerCategoryValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    category_id = val.to_i
    unless SiteSetting.allow_uncategorized_topics
      return false if category_id == SiteSetting.uncategorized_category_id
    end
    true
  end

  def error_message
    I18n.t("site_settings.errors.invalid_uncategorized_category_setting")
  end
end
