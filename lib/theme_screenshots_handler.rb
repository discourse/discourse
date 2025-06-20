# frozen_string_literal: true

class ThemeScreenshotsHandler
  MAX_THEME_SCREENSHOT_FILE_SIZE = 1.megabyte
  MAX_THEME_SCREENSHOT_DIMENSIONS = [3840, 2160] # 4K resolution
  MAX_THEME_SCREENSHOT_COUNT = 2
  THEME_SCREENSHOT_ALLOWED_FILE_TYPES = %w[.jpg .jpeg .gif .png].freeze

  class ThemeScreenshotError < StandardError
  end

  def initialize(theme)
    @theme = theme
  end

  # Screenshots here come from RemoteTheme.extract_theme_info, which
  # in turn parses the theme about.json file, which is where screenshots
  # are defined.
  def parse_screenshots_as_theme_fields!(screenshots, theme_importer)
    updated_theme_fields = []
    screenshots = Array.wrap(screenshots).take(MAX_THEME_SCREENSHOT_COUNT)
    screenshots.each do |relative_path|
      path = theme_importer.real_path(relative_path)
      next if !path.present?

      screenshot_filename = File.basename(path)
      screenshot_extension = File.extname(path)

      if !THEME_SCREENSHOT_ALLOWED_FILE_TYPES.include?(screenshot_extension)
        raise ThemeScreenshotError,
              I18n.t(
                "themes.import_error.screenshot_invalid_type",
                file_name: screenshot_filename,
                accepted_formats: THEME_SCREENSHOT_ALLOWED_FILE_TYPES.join(","),
              )
      end

      if File.size(path) > MAX_THEME_SCREENSHOT_FILE_SIZE
        raise ThemeScreenshotError,
              I18n.t(
                "themes.import_error.screenshot_invalid_size",
                file_name: screenshot_filename,
                max_size:
                  ActiveSupport::NumberHelper.number_to_human_size(MAX_THEME_SCREENSHOT_FILE_SIZE),
              )
      end

      screenshot_width, screenshot_height = FastImage.size(path)
      if (screenshot_width.nil? || screenshot_height.nil?) ||
           screenshot_width > MAX_THEME_SCREENSHOT_DIMENSIONS[0] ||
           screenshot_height > MAX_THEME_SCREENSHOT_DIMENSIONS[1]
        raise ThemeScreenshotError,
              I18n.t(
                "themes.import_error.screenshot_invalid_dimensions",
                file_name: screenshot_filename,
                width: screenshot_width.to_i,
                height: screenshot_height.to_i,
                max_width: MAX_THEME_SCREENSHOT_DIMENSIONS[0],
                max_height: MAX_THEME_SCREENSHOT_DIMENSIONS[1],
              )
      end

      upload =
        RemoteTheme.create_upload(
          theme: @theme,
          path: path,
          relative_path: relative_path,
          skip_validations: true,
        )
      if !upload.errors.empty?
        raise ThemeScreenshotError,
              I18n.t(
                "themes.import_error.screenshot",
                errors: upload.errors.full_messages.join(","),
              )
      end

      screenshot_filename_clean =
        FileHelper.sanitize_filename(screenshot_filename.gsub(screenshot_extension, ""))
      updated_theme_fields << @theme.set_field(
        target: :common,
        name: "screenshot_#{screenshot_filename_clean}",
        type: :theme_screenshot_upload_var,
        upload_id: upload.id,
      )
    end
    updated_theme_fields
  end
end
