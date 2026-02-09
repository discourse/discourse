# frozen_string_literal: true

class VideoConversionEnabledValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f" # Allow disabling video conversion

    # Check MediaConvert-specific requirements only when using aws_mediaconvert
    if SiteSetting.video_conversion_service == "aws_mediaconvert"
      # Check if MediaConvert role ARN is provided
      return false if SiteSetting.mediaconvert_role_arn.blank?

      # Check if S3 credentials are provided (either access keys or IAM profile)
      return false if s3_credentials_missing?
    end

    true
  end

  def error_message
    # Only check MediaConvert-specific requirements when using aws_mediaconvert
    if SiteSetting.video_conversion_service == "aws_mediaconvert"
      if SiteSetting.mediaconvert_role_arn.blank?
        I18n.t("site_settings.errors.mediaconvert_role_arn_required")
      elsif s3_credentials_missing?
        I18n.t("site_settings.errors.s3_credentials_required_for_video_conversion")
      end
    end
  end

  private

  def s3_credentials_missing?
    # Missing if exactly one credential is provided (broken partial config)
    (SiteSetting.s3_access_key_id.present? && SiteSetting.s3_secret_access_key.blank?) ||
      (SiteSetting.s3_access_key_id.blank? && SiteSetting.s3_secret_access_key.present?)
  end
end
