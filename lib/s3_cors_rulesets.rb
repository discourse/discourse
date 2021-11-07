# frozen_string_literal: true

require_dependency "s3_helper"

class S3CorsRulesets
  ASSETS = {
    allowed_headers: ["Authorization"],
    allowed_methods: ["GET", "HEAD"],
    allowed_origins: ["*"],
    max_age_seconds: 3000
  }.freeze

  BACKUP_DIRECT_UPLOAD = {
    allowed_headers: ["*"],
    expose_headers: ["ETag"],
    allowed_methods: ["GET", "HEAD", "PUT"],
    allowed_origins: ["*"],
    max_age_seconds: 3000
  }.freeze

  DIRECT_UPLOAD = {
    allowed_headers: ["Authorization", "Content-Disposition", "Content-Type"],
    expose_headers: ["ETag"],
    allowed_methods: ["GET", "HEAD", "PUT"],
    allowed_origins: ["*"],
    max_age_seconds: 3000
  }.freeze

  ##
  # Used by the s3:ensure_cors_rules rake task to make sure the
  # relevant CORS rules are applied to allow for direct uploads to
  # S3, and in the case of assets rules so there are fonts and other
  # public assets for the site loaded correctly.
  #
  # The use_db_s3_config param comes from ENV, and if the S3 client
  # is not provided it is initialized by the S3Helper.
  def self.sync(use_db_s3_config:, s3_client: nil)
    return if !SiteSetting.s3_install_cors_rule
    return if !(GlobalSetting.use_s3? || SiteSetting.enable_s3_uploads)

    assets_rules_applied = false
    backup_rules_applied = false
    direct_upload_rules_applied = false

    s3_helper = S3Helper.build_from_config(
      s3_client: s3_client, use_db_s3_config: use_db_s3_config
    )
    puts "Attempting to apply ASSETS S3 CORS ruleset in bucket #{s3_helper.s3_bucket_name}."
    assets_rules_applied = s3_helper.ensure_cors!([S3CorsRulesets::ASSETS])

    if SiteSetting.enable_backups? && SiteSetting.backup_location == BackupLocationSiteSetting::S3
      backup_s3_helper = S3Helper.build_from_config(
        s3_client: s3_client, use_db_s3_config: use_db_s3_config, for_backup: true
      )
      puts "Attempting to apply BACKUP_DIRECT_UPLOAD S3 CORS ruleset in bucket #{backup_s3_helper.s3_bucket_name}."
      backup_rules_applied = backup_s3_helper.ensure_cors!([S3CorsRulesets::BACKUP_DIRECT_UPLOAD])
    end

    if SiteSetting.enable_direct_s3_uploads
      puts "Attempting to apply DIRECT_UPLOAD S3 CORS ruleset in bucket #{s3_helper.s3_bucket_name}."
      direct_upload_rules_applied = s3_helper.ensure_cors!([S3CorsRulesets::DIRECT_UPLOAD])
    end

    {
      assets_rules_applied: assets_rules_applied,
      backup_rules_applied: backup_rules_applied,
      direct_upload_rules_applied: direct_upload_rules_applied
    }
  end
end
