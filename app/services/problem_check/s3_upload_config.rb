# frozen_string_literal: true

class ProblemCheck::S3UploadConfig < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if GlobalSetting.use_s3?
    return no_problem if !SiteSetting.enable_s3_uploads?
    return no_problem if SiteSetting.s3_upload_bucket.present?

    problem
  end
end
