# frozen_string_literal: true

RSpec.describe "Admin editing objects type" do
  let(:admin_objects_setting_editor_page) { PageObjects::Pages::AdminObjectsSettingEditor.new }

  fab!(:admin)
  before { sign_in(admin) }

  context "with translated fields" do
    fab!(:theme)
    let(:site_texts_page) { PageObjects::Pages::AdminSiteTexts.new }
    let(:key) { "resource_sections.getting_started.guidelines.label" }

    before do
      theme.set_field(
        target: :settings,
        name: "yaml",
        value: File.read(file_from_fixtures("translatable_objects.yaml", "theme_settings")),
      )
      theme.save!
    end

    it "previews nested keys and opens the component's translations in Site texts" do
      admin_objects_setting_editor_page.visit_theme(theme, "resource_sections")
      admin_objects_setting_editor_page.click_child_link("Community guidelines")
      expect(admin_objects_setting_editor_page).to have_translation_key(key)
      admin_objects_setting_editor_page.manage_translations
      expect(page).to have_current_path("/admin/customize/site_texts?theme_id=#{theme.id}")
      site_texts_page.select_locale("ja")
      site_texts_page.edit_translation(
        "js.theme_translations.#{theme.id}.#{key}",
        locale: "ja",
        theme_id: theme.id,
      )
      expect(page).to have_content("Default text · English")
      site_texts_page.override_translation("ガイドライン")
      expect(page).to have_css(".saved")
      expect(
        theme.theme_translation_overrides.find_by!(locale: "ja", translation_key: key).value,
      ).to eq("ガイドライン")
    end

    it "refreshes theme translations after saving object text" do
      themes_page = PageObjects::Pages::AdminCustomizeThemes.new
      themes_page.visit(theme)
      expect(themes_page).to have_translation(key, "Community guidelines")
      themes_page.click_edit_objects_setting_button("resource_sections")
      admin_objects_setting_editor_page.click_child_link("Community guidelines")
      admin_objects_setting_editor_page.fill_in_field("label", "Updated guidelines").save

      expect(themes_page).to have_translation(key, "Updated guidelines")
      page.refresh
      expect(themes_page).to have_translation(key, "Updated guidelines")
    end

    it "keeps the editor open and preserves saved values when identifiers conflict" do
      admin_objects_setting_editor_page.visit_theme(theme, "resource_sections")
      admin_objects_setting_editor_page.click_child_link("Community guidelines")
      admin_objects_setting_editor_page.fill_in_field("translation_key", "title").save
      expect(admin_objects_setting_editor_page).to have_validation_error
      expect(
        theme.reload.settings[:resource_sections].value[0]["links"][0]["translation_key"],
      ).to eq("guidelines")
    end
  end

  describe "when editing a theme setting of objects type" do
    fab!(:theme)

    let(:objects_setting) do
      theme.set_field(
        target: :settings,
        name: "yaml",
        value:
          File.read("#{Rails.root.join("spec/fixtures/theme_settings/objects_settings.yaml")}"),
      )

      theme.save!
      theme.settings[:objects_setting]
    end

    let(:admin_customize_themes_page) { PageObjects::Pages::AdminCustomizeThemes.new }

    before { objects_setting }

    it "displays property labels and descriptions from the locale file" do
      theme.set_field(
        target: :translations,
        name: "en",
        value:
          File.read("#{Rails.root.join("spec/fixtures/theme_locales/objects_settings/en.yaml")}"),
      )

      theme.save!

      admin_objects_setting_editor_page.visit_theme(theme, "objects_setting")

      expect(admin_objects_setting_editor_page).to have_setting_field_description(
        "name",
        "Section Name",
      )

      expect(admin_objects_setting_editor_page).to have_setting_field_label("name", "Name")

      admin_objects_setting_editor_page.click_child_link("link 1")

      expect(admin_objects_setting_editor_page).to have_setting_field_description(
        "name",
        "Name of the link",
      )

      expect(admin_objects_setting_editor_page).to have_setting_field_label("name", "Name")

      expect(admin_objects_setting_editor_page).to have_setting_field_description(
        "url",
        "URL of the link",
      )

      expect(admin_objects_setting_editor_page).to have_setting_field_label("url", "URL")
    end

    it "allows admins to edit an objects theme setting" do
      visit("/admin/customize/themes/#{theme.id}")

      expect(admin_customize_themes_page).to have_no_overriden_setting("objects_setting")

      expect(admin_customize_themes_page).to have_setting_description(
        "objects_setting",
        "This is a description for objects setting",
      )

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_setting_button("objects_setting")

      expect(page).to have_current_path(
        "/admin/customize/themes/#{theme.id}/schema/objects_setting",
      )

      admin_objects_theme_setting_editor.fill_in_field("name", "some new name").save

      expect(page).to have_current_path("/admin/customize/themes/#{theme.id}")

      expect(admin_customize_themes_page).to have_overridden_setting("objects_setting")

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_setting_button("objects_setting")

      expect(admin_objects_theme_setting_editor).to have_setting_field("name", "some new name")

      admin_objects_theme_setting_editor.back

      admin_customize_themes_page.reset_overridden_setting("objects_setting")

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_setting_button("objects_setting")

      expect(admin_objects_theme_setting_editor).to have_setting_field("name", "section 1")
    end

    it "displays the validation errors when an admin tries to save the setting with an invalid value" do
      visit("/admin/customize/themes/#{theme.id}")

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_setting_button("objects_setting")

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

    it "allows an admin to pick an icon for an icon type property" do
      SiteSetting.svg_icon_subset = "gamepad"

      theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
        links_setting:
          type: objects
          default:
            - title: link
              icon: heart
          schema:
            name: link
            properties:
              title:
                type: string
              icon:
                type: icon
      YAML
      theme.save!

      visit("/admin/customize/themes/#{theme.id}")

      admin_objects_theme_setting_editor =
        admin_customize_themes_page.click_edit_objects_setting_button("links_setting")

      icon_picker = PageObjects::Components::DIconGridPicker.new(".schema-field[data-name='icon']")

      expect(icon_picker).to have_selected_icon("heart")

      icon_picker.expand
      icon_picker.filter("gamepad")
      icon_picker.select_icon("gamepad")

      admin_objects_theme_setting_editor.save

      expect(theme.reload.settings[:links_setting].value).to eq(
        [{ "title" => "link", "icon" => "gamepad" }],
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

  describe "when editing a site setting of objects type" do
    before do
      SiteSetting.load_settings(
        Rails.root.join("spec/fixtures/site_settings/object_settings.yml").to_s,
      )
    end

    it "allows an admin to edit a site setting of objects type via the settings editor" do
      admin_objects_setting_editor_page.visit_setting("objects_setting")
      admin_objects_setting_editor_page.add_object_in_root.fill_in_field("name", "new section").save

      expect(page).to have_current_path("/admin/site_settings/category/required")
      expect(JSON.parse(SiteSetting.objects_setting)).to eq(
        [{ "links" => [], "name" => "new section" }],
      )
    end
  end
end
