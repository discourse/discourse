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
    objects_setting
    sign_in(admin)
  end

  describe "when editing a theme setting of objects type" do
    it "should display the right label and description for each property if the label and description has been configured in a locale file" do
      theme.set_field(
        target: :translations,
        name: "en",
        value: File.read("#{Rails.root}/spec/fixtures/theme_locales/objects_settings/en.yaml"),
      )

      theme.save!

      admin_objects_theme_setting_editor_page.visit(theme, "objects_setting")

      expect(admin_objects_theme_setting_editor_page).to have_setting_field_description(
        "name",
        "Section Name",
      )

      expect(admin_objects_theme_setting_editor_page).to have_setting_field_label("name", "Name")

      admin_objects_theme_setting_editor_page.click_child_link("link 1")

      expect(admin_objects_theme_setting_editor_page).to have_setting_field_description(
        "name",
        "Name of the link",
      )

      expect(admin_objects_theme_setting_editor_page).to have_setting_field_label("name", "Name")

      expect(admin_objects_theme_setting_editor_page).to have_setting_field_description(
        "url",
        "URL of the link",
      )

      expect(admin_objects_theme_setting_editor_page).to have_setting_field_label("url", "URL")
    end

    it "should allow admin to edit the theme setting of objects type" do
      visit("/admin/customize/themes/#{theme.id}")

      expect(admin_customize_themes_page).to have_no_overriden_setting("objects_setting")

      expect(admin_customize_themes_page).to have_setting_description(
        "objects_setting",
        "This is a description for objects setting",
      )

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_theme_setting_button("objects_setting")

      expect(page).to have_current_path(
        "/admin/customize/themes/#{theme.id}/schema/objects_setting",
      )

      admin_objects_theme_setting_editor.fill_in_field("name", "some new name").save

      expect(admin_customize_themes_page).to have_overridden_setting("objects_setting")

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_theme_setting_button("objects_setting")

      expect(admin_objects_theme_setting_editor).to have_setting_field("name", "some new name")

      admin_objects_theme_setting_editor.back

      admin_customize_themes_page.reset_overridden_setting("objects_setting")

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_theme_setting_button("objects_setting")

      expect(admin_objects_theme_setting_editor).to have_setting_field("name", "section 1")
    end

    it "displays the validation errors when an admin tries to save the settting with an invalid value" do
      visit("/admin/customize/themes/#{theme.id}")

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_theme_setting_button("objects_setting")

      admin_objects_theme_setting_editor
        .fill_in_field("name", "")
        .click_link("section 2")
        .fill_in_field("name", "")
        .click_child_link("link 1")
        .fill_in_field("name", "")
        .save

      expect(find(".schema-setting-editor__errors")).to have_text(
        "The property at JSON Pointer '/0/name' must be present. The property at JSON Pointer '/1/name' must be present. The property at JSON Pointer '/1/links/0/name' must be present.",
      )
    end

    it "allows an admin to edit a theme setting of objects type via the settings editor" do
      visit "/admin/customize/themes/#{theme.id}"

      theme_settings_editor = admin_customize_themes_page.click_theme_settings_editor_button

      theme_settings_editor.set_input(<<~SETTING)
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
        },
        {
          "setting": "objects_with_categories",
          "value": []
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
