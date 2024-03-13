# frozen_string_literal: true

RSpec.describe "Admin editing objects type theme setting", type: :system do
  fab!(:admin)
  fab!(:theme)

  let(:objects_setting) do
    theme.set_field(
      target: :settings,
      name: "yaml",
      value: File.read("#{Rails.root}/spec/fixtures/theme_settings/objects_settings.yaml"),
    )

    theme.save!
    theme.settings[:objects_setting]
  end

  let(:admin_customize_themes_page) { PageObjects::Pages::AdminCustomizeThemes.new }

  let(:admin_objects_theme_setting_editor_page) do
    PageObjects::Pages::AdminObjectsThemeSettingEditor.new
  end

  before do
    SiteSetting.experimental_objects_type_for_theme_settings = true
    objects_setting
    sign_in(admin)
  end

  describe "when editing a theme setting of objects type" do
    it "should allow admin to edit the theme setting of objects type" do
      visit("/admin/customize/themes/#{theme.id}")

      expect(admin_customize_themes_page).to have_no_overriden_setting("objects_setting")

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_theme_setting_button("objects_setting")

      expect(page).to have_current_path(
        "/admin/customize/themes/#{theme.id}/schema/objects_setting",
      )

      admin_objects_theme_setting_editor.fill_in_field("name", "some new name").save

      expect(admin_customize_themes_page).to have_overridden_setting("objects_setting")

      admin_customize_themes_page.reset_overridden_setting("objects_setting")

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_theme_setting_button("objects_setting")

      expect(admin_objects_theme_setting_editor).to have_setting_field("name", "some new name")
    end

    it "allows an admin to edit a theme setting of objects type via the settings editor" do
      visit "/admin/customize/themes/#{theme.id}"

      theme_settings_editor = admin_customize_themes_page.click_theme_settings_editor_button

      theme_settings_editor.fill_in(<<~SETTING)
      [
        {
          "setting": "objects_setting",
          "value": [
            {
              "name": "new section",
              "links": [
                {
                  "name": "new link",
                  "url": "https://example.com"
                }
              ]
            }
          ]
        }
      ]
      SETTING

      theme_settings_editor.save

      try_until_success do
        expect(theme.reload.settings[:objects_setting].value).to eq(
          [
            {
              "links" => [{ "name" => "new link", "url" => "https://example.com" }],
              "name" => "new section",
            },
          ],
        )
      end
    end
  end
end
