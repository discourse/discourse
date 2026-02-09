# frozen_string_literal: true

class ProblemCheck::S3BackupConfig < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if GlobalSetting.use_s3?
    return no_problem if SiteSetting.backup_location != BackupLocationSiteSetting::S3
    return no_problem if SiteSetting.s3_backup_bucket.present?

    problem
  end
end
