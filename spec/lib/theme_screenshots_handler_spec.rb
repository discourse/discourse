# frozen_string_literal: true

RSpec.describe ThemeScreenshotsHandler do
  subject(:handler) { ThemeScreenshotsHandler.new(theme) }

  fab!(:remote_theme) { RemoteTheme.create!(remote_url: "https://github.com/org/remote-theme1") }
  fab!(:theme) { Fabricate(:theme, remote_theme: remote_theme) }

  let(:importer) { ThemeStore::GitImporter.new("https://github.com/org/remote-theme1") }

  after(:each) { FileUtils.rm_rf(importer.temp_folder) }

  def write_temp_screenshots_for_importer(screenshots)
    FileUtils.mkdir_p("#{importer.temp_folder}/screenshots")

    # Random data is added to each file so the sha1 hash is different
    # and distinct uploads are created
    screenshots.each do |screenshot|
      File.write(
        "#{importer.temp_folder}/#{screenshot}",
        File.read(file_from_fixtures("logo.jpg", "images")) + SecureRandom.hex,
      )
    end
  end

  it "sanitizes filenames for screenshots before saving them" do
    screenshots = ["screenshots/light.jpeg", "screenshots/some Absolutely silly $%&* name --.jpeg"]
    write_temp_screenshots_for_importer(screenshots)
    handler.parse_screenshots_as_theme_fields!(screenshots, importer)
    theme.save!
    expect(theme.theme_fields.reload.map(&:name)).to match_array(
      %w[screenshot_light screenshot_some_Absolutely_silly_name_--],
    )
  end

  it "generates correct theme fields" do
    screenshots = %w[screenshots/light.jpeg screenshots/dark.jpeg]
    write_temp_screenshots_for_importer(screenshots)
    handler.parse_screenshots_as_theme_fields!(screenshots, importer)
    theme.save!
    expect(theme.theme_fields.pluck(:type_id)).to eq(
      [
        ThemeField.types[:theme_screenshot_upload_var],
        ThemeField.types[:theme_screenshot_upload_var],
      ],
    )
    expect(theme.theme_fields.pluck(:name)).to match_array(%w[screenshot_light screenshot_dark])
    expect(theme.theme_fields.pluck(:upload_id)).to match_array(Upload.last(2).pluck(:id))
  end

  it "raises an error if the screenshot is not an allowed file type" do
    screenshots = ["screenshots/light.tga"]
    write_temp_screenshots_for_importer(screenshots)
    expect { handler.parse_screenshots_as_theme_fields!(screenshots, importer) }.to raise_error(
      ThemeScreenshotsHandler::ThemeScreenshotError,
      I18n.t(
        "themes.import_error.screenshot_invalid_type",
        file_name: "light.tga",
        accepted_formats: ThemeScreenshotsHandler::THEME_SCREENSHOT_ALLOWED_FILE_TYPES.join(","),
      ),
    )
  end

  it "raises an error if the screenshot is too big" do
    screenshots = ["screenshots/light.jpeg"]
    write_temp_screenshots_for_importer(screenshots)
    stub_const(ThemeScreenshotsHandler, "MAX_THEME_SCREENSHOT_FILE_SIZE", 1.byte) do
      expect { handler.parse_screenshots_as_theme_fields!(screenshots, importer) }.to raise_error(
        ThemeScreenshotsHandler::ThemeScreenshotError,
        I18n.t(
          "themes.import_error.screenshot_invalid_size",
          file_name: "light.jpeg",
          max_size: "1 Bytes",
        ),
      )
    end
  end

  it "ignore max_image_size_kb site setting" do
    SiteSetting.max_image_size_kb = 1

    screenshots = ["screenshots/light.jpeg", "screenshots/some Absolutely silly $%&* name --.jpeg"]
    write_temp_screenshots_for_importer(screenshots)
    handler.parse_screenshots_as_theme_fields!(screenshots, importer)
    expect { theme.save! }.not_to raise_error
  end

  it "raises an error if the screenshot has invalid dimensions" do
    screenshots = ["screenshots/light.jpeg"]
    write_temp_screenshots_for_importer(screenshots)
    stub_const(ThemeScreenshotsHandler, "MAX_THEME_SCREENSHOT_DIMENSIONS", [1, 1]) do
      expect { handler.parse_screenshots_as_theme_fields!(screenshots, importer) }.to raise_error(
        ThemeScreenshotsHandler::ThemeScreenshotError,
        I18n.t(
          "themes.import_error.screenshot_invalid_dimensions",
          file_name: "light.jpeg",
          width: 512,
          height: 512,
          max_width: 1,
          max_height: 1,
        ),
      )
    end
  end
end
