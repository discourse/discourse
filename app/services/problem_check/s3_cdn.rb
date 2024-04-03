# frozen_string_literal: true

class ProblemCheck::S3Cdn < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !GlobalSetting.use_s3? && !SiteSetting.enable_s3_uploads?
    return no_problem if SiteSetting.Upload.s3_cdn_url.present?

    problem
  end
end
