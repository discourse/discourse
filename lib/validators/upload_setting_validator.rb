# frozen_string_literal: true

class UploadSettingValidator
  SPLASH_SCREEN_IMAGE_SETTINGS = %i[splash_screen_image splash_screen_image_dark].freeze

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?

    upload = Upload.find_by(id: val)
    upload.present? && additional_validation_passed(upload)
  end

  def error_message
    return I18n.t("site_settings.errors.invalid_svg") if splash_screen_image_setting?

    I18n.t("site_settings.errors.invalid_upload")
  end

  def additional_validation_passed(upload)
    return validate_svg(upload) if splash_screen_image_setting?

    true
  end

  # We also clean svgs in UploadCreator#clean_svg!,
  # but this is a good extra fallback.
  def validate_svg(upload)
    content =
      begin
        upload.content
      rescue StandardError
        nil
      end

    return false if content.blank?

    svg = Nokogiri.XML(content).at_css("svg")
    return false if svg.blank?

    has_scripts = svg.xpath("//*[local-name()='script']").present?
    has_event_handlers = svg.xpath("//@*[starts-with(local-name(), 'on')]").present?

    !has_scripts && !has_event_handlers
  end

  private

  def splash_screen_image_setting?
    SPLASH_SCREEN_IMAGE_SETTINGS.include?(@opts[:name])
  end
end
