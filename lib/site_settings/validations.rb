# frozen_string_literal: true

module SiteSettings
end

module SiteSettings::Validations
  PROHIBITED_USER_AGENT_STRINGS = %w[
    apple
    windows
    linux
    ubuntu
    gecko
    firefox
    chrome
    safari
    applewebkit
    webkit
    mozilla
    macintosh
    khtml
    intel
    osx
    os\ x
    iphone
    ipad
    mac
  ]

  def validate_error(key, opts = {})
    raise Discourse::InvalidParameters.new(I18n.t("errors.site_settings.#{key}", opts))
  end

  def validate_category_ids(category_ids)
    category_ids = category_ids.split("|").map(&:to_i).to_set
    if Category.where(id: category_ids).count != category_ids.size
      validate_error :invalid_category_id
    end
    category_ids
  end

  def validate_default_categories(category_ids, default_categories_selected)
    if (category_ids & default_categories_selected).size > 0
      validate_error :default_categories_already_selected
    end
  end

  def validate_default_categories_watching(new_val)
    category_ids = validate_category_ids(new_val)

    default_categories_selected = [
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_muted.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|"),
      SiteSetting.default_categories_normal.split("|"),
    ].flatten.map(&:to_i).to_set

    validate_default_categories(category_ids, default_categories_selected)
  end

  def validate_default_categories_tracking(new_val)
    category_ids = validate_category_ids(new_val)

    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_muted.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|"),
      SiteSetting.default_categories_normal.split("|"),
    ].flatten.map(&:to_i).to_set

    validate_default_categories(category_ids, default_categories_selected)
  end

  def validate_default_categories_muted(new_val)
    category_ids = validate_category_ids(new_val)

    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|"),
      SiteSetting.default_categories_normal.split("|"),
    ].flatten.map(&:to_i).to_set

    validate_default_categories(category_ids, default_categories_selected)
  end

  def validate_default_categories_watching_first_post(new_val)
    category_ids = validate_category_ids(new_val)

    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_muted.split("|"),
      SiteSetting.default_categories_normal.split("|"),
    ].flatten.map(&:to_i).to_set

    validate_default_categories(category_ids, default_categories_selected)
  end

  def validate_default_categories_normal(new_val)
    category_ids = validate_category_ids(new_val)

    default_categories_selected = [
      SiteSetting.default_categories_watching.split("|"),
      SiteSetting.default_categories_tracking.split("|"),
      SiteSetting.default_categories_muted.split("|"),
      SiteSetting.default_categories_watching_first_post.split("|"),
    ].flatten.map(&:to_i).to_set

    validate_default_categories(category_ids, default_categories_selected)
  end

  def validate_default_tags(tag_names, default_tags_selected)
    validate_error :default_tags_already_selected if (tag_names & default_tags_selected).size > 0
  end

  def validate_default_tags_watching(new_val)
    tag_names = new_val.split("|").to_set

    default_tags_selected = [
      SiteSetting.default_tags_tracking.split("|"),
      SiteSetting.default_tags_muted.split("|"),
      SiteSetting.default_tags_watching_first_post.split("|"),
    ].flatten.to_set

    validate_default_tags(tag_names, default_tags_selected)
  end

  def validate_default_tags_tracking(new_val)
    tag_names = new_val.split("|").to_set

    default_tags_selected = [
      SiteSetting.default_tags_watching.split("|"),
      SiteSetting.default_tags_muted.split("|"),
      SiteSetting.default_tags_watching_first_post.split("|"),
    ].flatten.to_set

    validate_default_tags(tag_names, default_tags_selected)
  end

  def validate_default_tags_muted(new_val)
    tag_names = new_val.split("|").to_set

    default_tags_selected = [
      SiteSetting.default_tags_watching.split("|"),
      SiteSetting.default_tags_tracking.split("|"),
      SiteSetting.default_tags_watching_first_post.split("|"),
    ].flatten.to_set

    validate_default_tags(tag_names, default_tags_selected)
  end

  def validate_default_tags_watching_first_post(new_val)
    tag_names = new_val.split("|").to_set

    default_tags_selected = [
      SiteSetting.default_tags_watching.split("|"),
      SiteSetting.default_tags_tracking.split("|"),
      SiteSetting.default_tags_muted.split("|"),
    ].flatten.to_set

    validate_default_tags(tag_names, default_tags_selected)
  end

  def validate_enable_s3_uploads(new_val)
    return if new_val == "f"
    validate_error :cannot_enable_s3_uploads_when_s3_enabled_globally if GlobalSetting.use_s3?
    validate_error :s3_upload_bucket_is_required if SiteSetting.s3_upload_bucket.blank?
  end

  def validate_secure_uploads(new_val)
    if new_val == "t" && (!SiteSetting.Upload.enable_s3_uploads || !SiteSetting.s3_use_acls)
      validate_error :secure_uploads_requirements
    end
  end

  def validate_enable_page_publishing(new_val)
    validate_error :page_publishing_requirements if new_val == "t" && SiteSetting.secure_uploads?
  end

  def validate_share_quote_buttons(new_val)
    if new_val.include?("facebook") && SiteSetting.facebook_app_id.blank?
      validate_error :share_quote_facebook_requirements
    end
  end

  def validate_backup_location(new_val)
    return unless new_val == BackupLocationSiteSetting::S3
    if SiteSetting.s3_backup_bucket.blank?
      validate_error(:s3_backup_requires_s3_settings, setting_name: "s3_backup_bucket")
    end

    # Only validate credentials if user is providing them
    # If neither provided, AWS SDK will auto-discover (role assumption, instance profile, etc.)
    if SiteSetting.s3_access_key_id.present? || SiteSetting.s3_secret_access_key.present?
      if SiteSetting.s3_access_key_id.blank?
        validate_error(:s3_backup_requires_s3_settings, setting_name: "s3_access_key_id")
      end
      if SiteSetting.s3_secret_access_key.blank?
        validate_error(:s3_backup_requires_s3_settings, setting_name: "s3_secret_access_key")
      end
    end
  end

  def validate_s3_upload_bucket(new_val)
    validate_bucket_setting("s3_upload_bucket", new_val, SiteSetting.s3_backup_bucket)

    if new_val.blank? && SiteSetting.enable_s3_uploads?
      validate_error(:s3_upload_bucket_is_required, setting_name: "s3_upload_bucket")
    end
  end

  def validate_s3_backup_bucket(new_val)
    validate_bucket_setting("s3_backup_bucket", SiteSetting.s3_upload_bucket, new_val)
  end

  def validate_enforce_second_factor(new_val)
    if new_val != "no" && SiteSetting.enable_discourse_connect?
      return validate_error :second_factor_cannot_be_enforced_with_discourse_connect_enabled
    end
    return if SiteSetting.enable_local_logins
    return if new_val == "no"
    validate_error :second_factor_cannot_be_enforced_with_disabled_local_login
  end

  def validate_enable_local_logins(new_val)
    return if new_val == "t"
    return if SiteSetting.enforce_second_factor == "no"
    validate_error :local_login_cannot_be_disabled_if_second_factor_enforced
  end

  def validate_cors_origins(new_val)
    return if new_val.blank?
    return if new_val.split("|").none?(%r{/\z})
    validate_error :cors_origins_should_not_have_trailing_slash
  end

  def validate_slow_down_crawler_user_agents(new_val)
    return if new_val.blank?

    new_val
      .downcase
      .split("|")
      .each do |crawler|
        if crawler.size < 3
          validate_error(:slow_down_crawler_user_agent_must_be_at_least_3_characters)
        end
        if PROHIBITED_USER_AGENT_STRINGS.any? { |c| c.include?(crawler) }
          validate_error(
            :slow_down_crawler_user_agent_cannot_be_popular_browsers,
            values: PROHIBITED_USER_AGENT_STRINGS.join(I18n.t("word_connector.comma")),
          )
        end
      end
  end

  def validate_strip_image_metadata(new_val)
    return if new_val == "t"
    return if SiteSetting.composer_media_optimization_image_enabled == false
    validate_error :strip_image_metadata_cannot_be_disabled_if_composer_media_optimization_image_enabled
  end

  def validate_x_summary_large_image(new_val)
    return if new_val.blank?
    return if !Upload.exists?(id: new_val, extension: "svg")
    validate_error :x_summary_large_image_no_svg
  end

  def validate_allow_all_users_to_flag_illegal_content(new_val)
    return if new_val == "f"
    if SiteSetting.contact_email.present? ||
         SiteSetting.email_address_to_report_illegal_content.present?
      return
    end

    validate_error :tl0_and_anonymous_flag
  end

  def validate_allow_likes_in_anonymous_mode(new_val)
    return if new_val == "f"
    return if SiteSetting.allow_anonymous_mode

    validate_error :allow_likes_in_anonymous_mode_without_anonymous_mode_enabled
  end

  private

  def validate_bucket_setting(setting_name, upload_bucket, backup_bucket)
    return if upload_bucket.blank? || backup_bucket.blank?

    backup_bucket_name, backup_prefix = split_s3_bucket(backup_bucket)
    upload_bucket_name, upload_prefix = split_s3_bucket(upload_bucket)

    return if backup_bucket_name != upload_bucket_name

    if backup_prefix == upload_prefix || backup_prefix.blank? ||
         upload_prefix&.start_with?(backup_prefix)
      validate_error(:s3_bucket_reused, setting_name: setting_name)
    end
  end

  def split_s3_bucket(s3_bucket)
    bucket_name, prefix = s3_bucket.downcase.split("/", 2)
    prefix&.chomp!("/")
    [bucket_name, prefix]
  end
end
