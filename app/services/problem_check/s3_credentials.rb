# frozen_string_literal: true

class ProblemCheck::S3Credentials < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !s3_enabled?
    if has_partial_credentials?
      return problem(override_key: "dashboard.problem.s3_credentials_partial")
    end
    return no_problem if has_explicit_credentials?

    problem
  end

  private

  def s3_enabled?
    GlobalSetting.use_s3? ||
      (SiteSetting.enable_s3_uploads? && SiteSetting.s3_upload_bucket.present?) ||
      (
        SiteSetting.backup_location == BackupLocationSiteSetting::S3 &&
          SiteSetting.s3_backup_bucket.present?
      )
  end

  def has_explicit_credentials?
    (SiteSetting.s3_access_key_id.present? && SiteSetting.s3_secret_access_key.present?) ||
      (GlobalSetting.s3_access_key_id.present? && GlobalSetting.s3_secret_access_key.present?)
  end

  def has_partial_credentials?
    site_partial =
      SiteSetting.s3_access_key_id.present? != SiteSetting.s3_secret_access_key.present?
    global_partial =
      GlobalSetting.s3_access_key_id.present? != GlobalSetting.s3_secret_access_key.present?
    site_partial || global_partial
  end
end
