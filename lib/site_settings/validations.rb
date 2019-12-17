# frozen_string_literal: true

module SiteSettings; end

module SiteSettings::Validations
  def validate_error(key, opts = {})
    raise Discourse::InvalidParameters.new(I18n.t("errors.site_settings.#{key}", opts))
  end

  def validate_category_ids(category_ids)
    category_ids = category_ids.split('|').map(&:to_i).to_set
    validate_error :invalid_category_id if Category.where(id: category_ids).count != category_ids.size
    category_ids
  end

  def validate_default_categories(category_ids, default_categories_selected)
    validate_error :default_categories_already_selected if (category_ids & default_categories_selected).size > 0
  end

  def validate_default_categories_watching(new_val)
    category_ids = validate_category_ids(new_val)

    default_categories_selected = [
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_muted.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|")
    ].flatten.map(&:to_i).to_set

    validate_default_categories(category_ids, default_categories_selected)
  end

  def validate_default_categories_tracking(new_val)
    category_ids = validate_category_ids(new_val)

    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_muted.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|")
    ].flatten.map(&:to_i).to_set

    validate_default_categories(category_ids, default_categories_selected)
  end

  def validate_default_categories_muted(new_val)
    category_ids = validate_category_ids(new_val)

    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|")
    ].flatten.map(&:to_i).to_set

    validate_default_categories(category_ids, default_categories_selected)
  end

  def validate_default_categories_watching_first_post(new_val)
    category_ids = validate_category_ids(new_val)

    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_muted.split("|")
    ].flatten.map(&:to_i).to_set

    validate_default_categories(category_ids, default_categories_selected)
  end

  def validate_default_tags(tag_names, default_tags_selected)
    validate_error :default_tags_already_selected if (tag_names & default_tags_selected).size > 0
  end

  def validate_default_tags_watching(new_val)
    tag_names = new_val.split('|').to_set

    default_tags_selected = [
      SiteSetting.default_tags_tracking.split("|"),
      SiteSetting.default_tags_muted.split("|"),
      SiteSetting.default_tags_watching_first_post.split("|")
    ].flatten.to_set

    validate_default_tags(tag_names, default_tags_selected)
  end

  def validate_default_tags_tracking(new_val)
    tag_names = new_val.split('|').to_set

    default_tags_selected = [
      SiteSetting.default_tags_watching.split("|"),
      SiteSetting.default_tags_muted.split("|"),
      SiteSetting.default_tags_watching_first_post.split("|")
    ].flatten.to_set

    validate_default_tags(tag_names, default_tags_selected)
  end

  def validate_default_tags_muted(new_val)
    tag_names = new_val.split('|').to_set

    default_tags_selected = [
      SiteSetting.default_tags_watching.split("|"),
      SiteSetting.default_tags_tracking.split("|"),
      SiteSetting.default_tags_watching_first_post.split("|")
    ].flatten.to_set

    validate_default_tags(tag_names, default_tags_selected)
  end

  def validate_default_tags_watching_first_post(new_val)
    tag_names = new_val.split('|').to_set

    default_tags_selected = [
      SiteSetting.default_tags_watching.split("|"),
      SiteSetting.default_tags_tracking.split("|"),
      SiteSetting.default_tags_muted.split("|")
    ].flatten.to_set

    validate_default_tags(tag_names, default_tags_selected)
  end

  def validate_enable_s3_uploads(new_val)
    return if new_val == "f"
    validate_error :cannot_enable_s3_uploads_when_s3_enabled_globally if GlobalSetting.use_s3?
    validate_error :s3_upload_bucket_is_required if SiteSetting.s3_upload_bucket.blank?
  end

  def validate_secure_media(new_val)
    validate_error :secure_media_requirements if new_val == "t" && !SiteSetting.Upload.enable_s3_uploads
  end

  def validate_enable_s3_inventory(new_val)
    validate_error :enable_s3_uploads_is_required if new_val == "t" && !SiteSetting.Upload.enable_s3_uploads
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

  def validate_enforce_second_factor(new_val)
    return if SiteSetting.enable_local_logins
    return if new_val == "no"
    validate_error :second_factor_cannot_be_enforced_with_disabled_local_login
  end

  def validate_enable_local_logins(new_val)
    return if new_val == "t"
    return if SiteSetting.enforce_second_factor == "no"
    validate_error :local_login_cannot_be_disabled_if_second_factor_enforced
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
