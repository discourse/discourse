# frozen_string_literal: true

class MediaconvertOutputSubdirectoryValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    # Value must be present (not blank)
    val.present?
  end

  def error_message
    I18n.t("site_settings.errors.mediaconvert_output_subdirectory_required")
  end
end
