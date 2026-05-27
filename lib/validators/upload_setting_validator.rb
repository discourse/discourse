# frozen_string_literal: true

class UploadSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?

    upload = Upload.find_by(id: val)
    upload.present? && additional_validation_passed(upload)
  end

  def error_message
    return I18n.t("site_settings.errors.invalid_svg") if @opts[:name] == :splash_screen_image
    I18n.t("site_settings.errors.invalid_upload")
  end

  def additional_validation_passed(upload)
    if @opts[:name] == :splash_screen_image
      validate_svg(upload)
    else
      true
    end
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
end
