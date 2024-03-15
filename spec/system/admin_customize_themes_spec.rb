# frozen_string_literal: true

describe "Admin Customize Themes", type: :system do
  fab!(:color_scheme)
  fab!(:theme)
  fab!(:admin)

  let(:admin_customize_themes_page) { PageObjects::Pages::AdminCustomizeThemes.new }

  before { sign_in(admin) }

  describe "when visiting the page to customize themes" do
    fab!(:theme_2) { Fabricate(:theme) }
    fab!(:theme_3) { Fabricate(:theme) }
    let(:delete_themes_confirm_modal) { PageObjects::Modals::DeleteThemesConfirm.new }

    it "should allow admin to bulk delete inactive themes" do
      visit("/admin/customize/themes")

      expect(admin_customize_themes_page).to have_inactive_themes

      admin_customize_themes_page.click_select_inactive_mode
      expect(admin_customize_themes_page).to have_inactive_themes_selected(count: 0)
      admin_customize_themes_page.toggle_all_inactive
      expect(admin_customize_themes_page).to have_inactive_themes_selected(count: 3)

      admin_customize_themes_page.cancel_select_inactive_mode
      expect(admin_customize_themes_page).to have_select_inactive_mode_button

      admin_customize_themes_page.click_select_inactive_mode
      expect(admin_customize_themes_page).to have_disabled_delete_theme_button

      admin_customize_themes_page.toggle_all_inactive

      admin_customize_themes_page.click_delete_themes_button

      expect(delete_themes_confirm_modal).to have_theme(theme.name)
      expect(delete_themes_confirm_modal).to have_theme(theme_2.name)
      expect(delete_themes_confirm_modal).to have_theme(theme_3.name)
      delete_themes_confirm_modal.confirm

      expect(admin_customize_themes_page).to have_no_inactive_themes
    end

    it "selects the themes tab by default" do
      visit("/admin/customize/themes")
      expect(find(".themes-list-header")).to have_css(".themes-tab.active")
    end

    it "selects the component tab when visiting the theme-components route" do
      visit("/admin/customize/theme-components")
      expect(find(".themes-list-header")).to have_css(".components-tab.active")
    end
  end

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
      theme_translations_picker = PageObjects::Components::AdminThemeTranslationsPicker.new

      theme_translations_picker.fill_in("Franç")
      theme_translations_picker.save

      theme_translations_settings_editor =
        PageObjects::Components::AdminThemeTranslationsSettingsEditor.new
      expect(theme_translations_settings_editor.get_input_value).to have_content("Bonjour!")

      theme_translations_settings_editor.fill_in("Hello World in French")
      theme_translations_settings_editor.save

      visit("/admin/customize/themes/#{theme.id}")

      expect(theme_translations_settings_editor.get_input_value).to have_content("Hello there!")

      theme_translations_picker.fill_in("Franç")
      theme_translations_picker.save

      expect(theme_translations_settings_editor.get_input_value).to have_content(
        "Hello World in French",
      )
    end
  end
end
