# frozen_string_literal: true

class ProblemCheck::S3UploadConfig < ProblemCheck::S3Config
  private

  def s3_enabled?
    SiteSetting.enable_s3_uploads?
  end

  def bucket_setting
    :s3_upload_bucket
  end
end
