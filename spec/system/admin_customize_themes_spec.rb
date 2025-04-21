# frozen_string_literal: true

describe "Admin Customize Themes", type: :system do
  fab!(:color_scheme)
  fab!(:theme) { Fabricate(:theme, name: "Cool theme 1") }
  fab!(:admin) { Fabricate(:admin, locale: "en") }

  let(:admin_customize_themes_page) { PageObjects::Pages::AdminCustomizeThemes.new }

  before { sign_in(admin) }

  describe "when visiting the page to customize a single theme" do
    it "should allow admin to update the color scheme of the theme" do
      visit("/admin/customize/themes/#{theme.id}")

      color_scheme_settings = find(".theme-settings__color-scheme")

      expect(color_scheme_settings).not_to have_css(".submit-edit")
      expect(color_scheme_settings).not_to have_css(".cancel-edit")

      color_scheme_settings.find(".color-palettes").click
      color_scheme_settings.find(".color-palettes-row[data-value='#{color_scheme.id}']").click
      color_scheme_settings.find(".submit-edit").click

      expect(color_scheme_settings.find(".setting-value")).to have_content(color_scheme.name)
      expect(color_scheme_settings).not_to have_css(".submit-edit")
      expect(color_scheme_settings).not_to have_css(".cancel-edit")
    end
  end

  describe "when editing a local theme" do
    it "The saved value is present in the editor" do
      theme.set_field(target: "common", name: "head_tag", value: "console.log('test')", type_id: 0)
      theme.save!

      visit("/admin/customize/themes/#{theme.id}/common/head_tag/edit")

      ace_content = find(".ace_content")
      expect(ace_content.text).to eq("console.log('test')")
    end

    it "can edit the js field" do
      visit("/admin/customize/themes/#{theme.id}/common/js/edit")

      ace_content = find(".ace_content")
      expect(ace_content.text).to include("// Your code here")
      find(".ace_text-input", visible: false).fill_in(with: "console.log('test')\n")
      find(".save-theme").click

      try_until_success do
        expect(
          theme.theme_fields.find_by(target_id: Theme.targets[:extra_js])&.value,
        ).to start_with("console.log('test')\n")
      end

      # Check content is loaded from db correctly
      theme
        .theme_fields
        .find_by(target_id: Theme.targets[:extra_js])
        .update!(value: "console.log('second test')")
      visit("/admin/customize/themes/#{theme.id}/common/js/edit")
      ace_content = find(".ace_content")
      expect(ace_content.text).to include("console.log('second test')")
    end
  end

  describe "when editing theme translations" do
    it "should allow admin to edit and save the theme translations" do
      theme.set_field(
        target: :translations,
        name: "en",
        value: { en: { group: { hello: "Hello there!" } } }.deep_stringify_keys.to_yaml,
      )

      theme.save!

      visit("/admin/customize/themes/#{theme.id}")

      theme_translations_settings_editor =
        PageObjects::Components::AdminThemeTranslationsSettingsEditor.new

      theme_translations_settings_editor.fill_in("Hello World")
      theme_translations_settings_editor.save

      visit("/admin/customize/themes/#{theme.id}")

      expect(theme_translations_settings_editor.get_input_value).to have_content("Hello World")
    end

    it "should allow admin to edit and save the theme translations from other languages" do
      theme.set_field(
        target: :translations,
        name: "en",
        value: { en: { group: { hello: "Hello there!" } } }.deep_stringify_keys.to_yaml,
      )
      theme.set_field(
        target: :translations,
        name: "fr",
        value: { fr: { group: { hello: "Bonjour!" } } }.deep_stringify_keys.to_yaml,
      )
      theme.save!

      visit("/admin/customize/themes/#{theme.id}")

      theme_translations_settings_editor =
        PageObjects::Components::AdminThemeTranslationsSettingsEditor.new
      expect(theme_translations_settings_editor.get_input_value).to have_content("Hello there!")

      theme_translations_picker = PageObjects::Components::SelectKit.new(".translation-selector")
      theme_translations_picker.select_row_by_value("fr")

      expect(page).to have_css(".translations")

      expect(theme_translations_settings_editor.get_input_value).to have_content("Bonjour!")

      theme_translations_settings_editor.fill_in("Hello World in French")
      theme_translations_settings_editor.save
    end

    it "should match the current user locale translation" do
      SiteSetting.allow_user_locale = true
      SiteSetting.set_locale_from_accept_language_header = true
      SiteSetting.default_locale = "fr"

      theme.set_field(
        target: :translations,
        name: "en",
        value: { en: { group: { hello: "Hello there!" } } }.deep_stringify_keys.to_yaml,
      )
      theme.set_field(
        target: :translations,
        name: "fr",
        value: { fr: { group: { hello: "Bonjour!" } } }.deep_stringify_keys.to_yaml,
      )
      theme.save!

      visit("/admin/customize/themes/#{theme.id}")

      theme_translations_settings_editor =
        PageObjects::Components::AdminThemeTranslationsSettingsEditor.new

      expect(theme_translations_settings_editor.get_input_value).to have_content("Hello there!")

      theme_translations_picker = PageObjects::Components::SelectKit.new(".translation-selector")
      expect(theme_translations_picker.component.text).to eq("English (US)")
    end
  end

  # TODO(osama) unskip this test when the "Themes and components" link is
  # changed to the new config customize page
  context "when visting a theme's page" do
    xit "has a link to the themes page" do
      visit("/admin/customize/themes/#{theme.id}")
      expect(admin_customize_themes_page).to have_back_button_to_themes_page
    end
  end

  context "when visting a component's page" do
    fab!(:component) { Fabricate(:theme, component: true, name: "Cool component 493") }

    xit "has a link to the components page" do
      visit("/admin/customize/themes/#{component.id}")
      expect(admin_customize_themes_page).to have_back_button_to_components_page
    end
  end
end
