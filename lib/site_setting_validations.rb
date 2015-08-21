
module SiteSettingValidations

  def validate_error(key)
    raise Discourse::InvalidParameters.new(I18n.t("errors.site_settings.#{key}"))
  end

  def validate_min_username_length(new_val)
    validate_error :min_username_length_range if new_val > SiteSetting.max_username_length
    validate_error :min_username_length_exists if User.where('length(username) < ?', new_val).exists?
  end

  def validate_max_username_length(new_val)
    validate_error :min_username_length_range if new_val < SiteSetting.min_username_length
    validate_error :max_username_length_exists if User.where('length(username) > ?', new_val).exists?
  end

  def validate_default_categories(new_val)
    validate_error :default_categories_already_selected if (new_val.split("|").to_set & SiteSetting.default_categories_selected).size > 0
  end

  alias_method :validate_default_categories_watching, :validate_default_categories
  alias_method :validate_default_categories_tracking, :validate_default_categories
  alias_method :validate_default_categories_muted, :validate_default_categories

end
