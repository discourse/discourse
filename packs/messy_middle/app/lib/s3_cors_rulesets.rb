# frozen_string_literal: true

require "s3_helper"

class S3CorsRulesets
  ASSETS = {
    allowed_headers: ["Authorization"],
    allowed_methods: %w[GET HEAD],
    allowed_origins: ["*"],
    max_age_seconds: 3000,
  }.freeze

  BACKUP_DIRECT_UPLOAD = {
    allowed_headers: ["*"],
    expose_headers: ["ETag"],
    allowed_methods: %w[GET HEAD PUT],
    allowed_origins: ["*"],
    max_age_seconds: 3000,
  }.freeze

  DIRECT_UPLOAD = {
    allowed_headers: %w[Authorization Content-Disposition Content-Type],
    expose_headers: ["ETag"],
    allowed_methods: %w[GET HEAD PUT],
    allowed_origins: ["*"],
    max_age_seconds: 3000,
  }.freeze

  RULE_STATUS_SKIPPED = "rules_skipped_from_settings"
  RULE_STATUS_EXISTED = "rules_already_existed"
  RULE_STATUS_APPLIED = "rules_applied"

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

    assets_rules_status = RULE_STATUS_SKIPPED
    backup_rules_status = RULE_STATUS_SKIPPED
    direct_upload_rules_status = RULE_STATUS_SKIPPED

    s3_helper = S3Helper.build_from_config(s3_client: s3_client, use_db_s3_config: use_db_s3_config)
    if !Rails.env.test?
      puts "Attempting to apply ASSETS S3 CORS ruleset in bucket #{s3_helper.s3_bucket_name}."
    end
    assets_rules_status =
      s3_helper.ensure_cors!([S3CorsRulesets::ASSETS]) ? RULE_STATUS_APPLIED : RULE_STATUS_EXISTED

    if SiteSetting.enable_backups? && SiteSetting.backup_location == BackupLocationSiteSetting::S3
      backup_s3_helper =
        S3Helper.build_from_config(
          s3_client: s3_client,
          use_db_s3_config: use_db_s3_config,
          for_backup: true,
        )
      if !Rails.env.test?
        puts "Attempting to apply BACKUP_DIRECT_UPLOAD S3 CORS ruleset in bucket #{backup_s3_helper.s3_bucket_name}."
      end
      backup_rules_status =
        (
          if backup_s3_helper.ensure_cors!([S3CorsRulesets::BACKUP_DIRECT_UPLOAD])
            RULE_STATUS_APPLIED
          else
            RULE_STATUS_EXISTED
          end
        )
    end

    if SiteSetting.enable_direct_s3_uploads
      if !Rails.env.test?
        puts "Attempting to apply DIRECT_UPLOAD S3 CORS ruleset in bucket #{s3_helper.s3_bucket_name}."
      end
      direct_upload_rules_status =
        (
          if s3_helper.ensure_cors!([S3CorsRulesets::DIRECT_UPLOAD])
            RULE_STATUS_APPLIED
          else
            RULE_STATUS_EXISTED
          end
        )
    end

    {
      assets_rules_status: assets_rules_status,
      backup_rules_status: backup_rules_status,
      direct_upload_rules_status: direct_upload_rules_status,
    }
  end
end
