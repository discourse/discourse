# frozen_string_literal: true

class ProblemCheck::S3BackupConfig < ProblemCheck::S3Config
  private

  def s3_enabled?
    SiteSetting.backup_location == BackupLocationSiteSetting::S3
  end

  def bucket_setting
    :s3_backup_bucket
  end
end
