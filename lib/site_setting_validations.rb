
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

  def validate_default_categories(new_val, default_categories_selected)
    validate_error :default_categories_already_selected if (new_val.split("|").to_set & default_categories_selected).size > 0
  end

  def validate_default_categories_watching(new_val)
    default_categories_selected = [
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_muted.split("|"),
    ].flatten.to_set

    validate_default_categories(new_val, default_categories_selected)
  end

  def validate_default_categories_tracking(new_val)
    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_muted.split("|"),
    ].flatten.to_set

    validate_default_categories(new_val, default_categories_selected)
  end

  def validate_default_categories_muted(new_val)
    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_tracking.split("|"),
    ].flatten.to_set

    validate_default_categories(new_val, default_categories_selected)
  end

  def validate_enable_s3_uploads(new_val)
    validate_error :s3_upload_bucket_is_required if new_val == "t" && SiteSetting.s3_upload_bucket.blank?
  end

end
