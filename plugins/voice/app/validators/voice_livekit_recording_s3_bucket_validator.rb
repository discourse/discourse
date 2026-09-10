# frozen_string_literal: true

class VoiceLivekitRecordingS3BucketValidator
  include RegexSettingValidation

  def initialize(opts = {})
    initialize_regex_opts(opts)
  end

  def valid_value?(value)
    @error_key = nil
    @regex_fail = false
    return true if value.blank?
    return false if !regex_match?(value)

    @error_key =
      if SiteSetting.voice_livekit_recording_s3_access_key_id.blank? ||
           SiteSetting.voice_livekit_recording_s3_secret_access_key.blank?
        "voice_livekit_recording_s3_requires_credentials"
      elsif SiteSetting.voice_livekit_recording_s3_region.blank? &&
            SiteSetting.voice_livekit_recording_s3_endpoint.blank?
        "voice_livekit_recording_s3_requires_region"
      elsif !SiteSetting.voice_livekit_url.start_with?("wss://")
        "voice_livekit_recording_s3_requires_wss"
      end

    @error_key.nil?
  end

  def error_message
    return I18n.t(@regex_error) if @regex_fail

    I18n.t("site_settings.errors.#{@error_key}") if @error_key
  end
end
