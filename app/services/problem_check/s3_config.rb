# frozen_string_literal: true

class ProblemCheck::S3Config < ProblemCheck
  def call
    return no_problem if GlobalSetting.use_s3?
    return no_problem if !s3_enabled?
    return no_problem if missing_settings.empty?

    problem
  end

  private

  def s3_enabled?
    raise NotImplementedError
  end

  def bucket_setting
    raise NotImplementedError
  end

  # An IAM profile stands in for the access keys.
  def missing_settings
    settings = SiteSetting.s3_use_iam_profile ? [] : %i[s3_access_key_id s3_secret_access_key]

    (settings << bucket_setting).select { SiteSetting.get(it).blank? }
  end

  def translation_data
    { missing_settings: SiteSettings::LabelFormatter.setting_markers(missing_settings) }
  end
end
