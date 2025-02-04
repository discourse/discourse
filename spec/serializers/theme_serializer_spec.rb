# frozen_string_literal: true

RSpec.describe ThemeSerializer do
  describe "load theme settings" do
    fab!(:theme)

    it "should add error message when settings format is invalid" do
      Theme
        .any_instance
        .stubs(:settings)
        .raises(ThemeSettingsParser::InvalidYaml, I18n.t("themes.settings_errors.invalid_yaml"))
      serialized = ThemeSerializer.new(theme).as_json[:theme]
      expect(serialized[:settings]).to be_nil
      expect(serialized[:errors].count).to eq(1)
      expect(serialized[:errors][0]).to eq(I18n.t("themes.settings_errors.invalid_yaml"))
    end

    it "should add errors messages from theme fields" do
      error = "error when compiling theme field"
      theme_field = Fabricate(:theme_field, error: error, theme: theme)
      serialized = ThemeSerializer.new(theme.reload).as_json[:theme]
      expect(serialized[:errors].count).to eq(1)
      expect(serialized[:errors][0]).to eq(error)
    end
  end

  describe "screenshot_url" do
    fab!(:theme)
    let(:serialized) { ThemeSerializer.new(theme.reload).as_json[:theme] }

    it "should include screenshot_url when there is a theme field with screenshot upload type" do
      Fabricate(
        :theme_field,
        theme: theme,
        type_id: ThemeField.types[:theme_screenshot_upload_var],
        name: "theme_screenshot_1",
        upload: Fabricate(:upload),
      )
      expect(serialized[:screenshot_url]).to be_present
    end

    it "should not include screenshot_url when there is no theme field with screenshot upload type" do
      expect(serialized[:screenshot_url]).to be_nil
    end

    it "should handle multiple screenshot fields and use the first one" do
      first_upload = Fabricate(:upload)
      second_upload = Fabricate(:upload)
      Fabricate(
        :theme_field,
        theme: theme,
        type_id: ThemeField.types[:theme_screenshot_upload_var],
        name: "theme_screenshot_1",
        upload: first_upload,
      )
      Fabricate(
        :theme_field,
        theme: theme,
        type_id: ThemeField.types[:theme_screenshot_upload_var],
        name: "theme_screenshot_2",
        upload: second_upload,
      )

      expect(serialized[:screenshot_url]).to eq(first_upload.url)
    end
  end
end
