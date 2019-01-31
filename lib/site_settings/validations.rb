module SiteSettings; end

module SiteSettings::Validations
  def validate_error(key, opts = {})
    raise Discourse::InvalidParameters.new(I18n.t("errors.site_settings.#{key}", opts))
  end

  def validate_default_categories(new_val, default_categories_selected)
    validate_error :default_categories_already_selected if (new_val.split("|").to_set & default_categories_selected).size > 0
  end

  def validate_default_categories_watching(new_val)
    default_categories_selected = [
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_muted.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|")
    ].flatten.to_set

    validate_default_categories(new_val, default_categories_selected)
  end

  def validate_default_categories_tracking(new_val)
    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_muted.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|")
    ].flatten.to_set

    validate_default_categories(new_val, default_categories_selected)
  end

  def validate_default_categories_muted(new_val)
    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|")
    ].flatten.to_set

    validate_default_categories(new_val, default_categories_selected)
  end

  def validate_default_categories_watching_first_post(new_val)
    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_muted.split("|")
    ].flatten.to_set

    validate_default_categories(new_val, default_categories_selected)
  end

  def validate_enable_s3_uploads(new_val)
    validate_error :s3_upload_bucket_is_required if new_val == "t" && SiteSetting.s3_upload_bucket.blank?
  end

  def validate_backup_location(new_val)
    return unless new_val == BackupLocationSiteSetting::S3
    validate_error(:s3_backup_requires_s3_settings, setting_name: "s3_backup_bucket") if SiteSetting.s3_backup_bucket.blank?

    unless SiteSetting.s3_use_iam_profile
      validate_error(:s3_backup_requires_s3_settings, setting_name: "s3_access_key_id") if SiteSetting.s3_access_key_id.blank?
      validate_error(:s3_backup_requires_s3_settings, setting_name: "s3_secret_access_key") if SiteSetting.s3_secret_access_key.blank?
    end
  end

  def validate_s3_upload_bucket(new_val)
    validate_bucket_setting("s3_upload_bucket", new_val, SiteSetting.s3_backup_bucket)
  end

  def validate_s3_backup_bucket(new_val)
    validate_bucket_setting("s3_backup_bucket", SiteSetting.s3_upload_bucket, new_val)
  end

  private

  def validate_bucket_setting(setting_name, upload_bucket, backup_bucket)
    return if upload_bucket.blank? || backup_bucket.blank?

    backup_bucket_name, backup_prefix = split_s3_bucket(backup_bucket)
    upload_bucket_name, upload_prefix = split_s3_bucket(upload_bucket)

    return if backup_bucket_name != upload_bucket_name

    if backup_prefix == upload_prefix || backup_prefix.blank? || upload_prefix&.start_with?(backup_prefix)
      validate_error(:s3_bucket_reused, setting_name: setting_name)
    end
  end

  def split_s3_bucket(s3_bucket)
    bucket_name, prefix = s3_bucket.downcase.split("/", 2)
    prefix&.chomp!("/")
    [bucket_name, prefix]
  end
end
