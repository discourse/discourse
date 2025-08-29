# frozen_string_literal: true

describe "Admin Customize Themes", type: :system do
  fab!(:color_scheme) do
    Fabricate(:color_scheme, base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Light"])
  end
  fab!(:theme) { Fabricate(:theme, name: "Cool theme 1", user_selectable: true) }
  fab!(:admin) { Fabricate(:admin, locale: "en") }

  let(:theme_page) { PageObjects::Pages::AdminCustomizeThemes.new }
  let(:themes_page) { PageObjects::Pages::AdminCustomizeThemesConfigArea.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(admin) }

  describe "when visiting the page to customize a single theme" do
    it "should allow admin to update the light color scheme of the theme" do
      theme_page.visit(theme)

      color_scheme_settings = find(".theme-settings__light-color-scheme")

      expect(color_scheme_settings).to have_no_css(".submit-light-edit")
      expect(color_scheme_settings).to have_no_css(".cancel-light-edit")

      color_scheme_settings.find(".color-palette-picker").click
      color_scheme_settings.find(".color-palette-picker-row[data-value='#{color_scheme.id}']").click
      color_scheme_settings.find(".submit-light-edit").click

      expect(color_scheme_settings.find(".setting-value")).to have_content(color_scheme.name)
      expect(color_scheme_settings).to have_no_css(".submit-light-edit")
      expect(color_scheme_settings).to have_no_css(".cancel-light-edit")

      expect(page).to have_link(
        I18n.t("admin_js.admin.customize.theme.edit_colors"),
        href: "/admin/config/colors/#{color_scheme.id}",
      )
    end

    it "should allow admin to update the dark color scheme of the theme" do
      theme_page.visit(theme)

      color_scheme_settings = find(".theme-settings__dark-color-scheme")

      expect(color_scheme_settings).not_to have_css(".submit-dark-edit")
      expect(color_scheme_settings).not_to have_css(".cancel-dark-edit")

      color_scheme_settings.find(".color-palette-picker").click
      color_scheme_settings.find(".color-palette-picker-row[data-value='#{color_scheme.id}']").click
      color_scheme_settings.find(".submit-dark-edit").click

      expect(color_scheme_settings.find(".setting-value")).to have_content(color_scheme.name)
      expect(color_scheme_settings).not_to have_css(".submit-dark-edit")
      expect(color_scheme_settings).not_to have_css(".cancel-dark-edit")

      expect(page).to have_link(
        I18n.t("admin_js.admin.customize.theme.edit_colors"),
        href: "/admin/config/colors/#{color_scheme.id}",
      )
    end

    it "allows a theme to be deleted" do
      theme_page.visit(theme).click_delete_button_and_confirm

      expect(PageObjects::Components::Toasts.new).to have_success(
        I18n.t("admin_js.admin.customize.theme.delete_success", theme: theme.name),
      )

      expect(page).to have_current_path("/admin/config/customize/themes")
      expect(themes_page).to have_no_theme(theme.name)
    end
  end

  describe "when editing a local theme" do
    it "The saved value is present in the editor" do
      theme.set_field(target: "common", name: "head_tag", value: "console.log('test')", type_id: 0)
      theme.save!

      visit("/admin/customize/themes/#{theme.id}/common/head_tag/edit")

      expect(find(".ace_content")).to have_content("console.log('test')")
    end

    it "can edit the js field" do
      visit("/admin/customize/themes/#{theme.id}/common/js/edit")

      expect(find(".ace_content")).to have_content("// Your code here")
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

      expect(find(".ace_content")).to have_content("console.log('second test')")
    end
  end

  it "cannot edit js, upload files or delete system themes" do
    theme.update_columns(id: -10)
    theme_page.visit(theme)
    expect(page).to have_css(".system-theme-info")
    expect(page).to have_css(".title button")
    expect(page).to have_no_css(".title button svg")
    expect(page).to have_no_css(".edit-code")
    expect(page).to have_no_css("button.upload")
    expect(page).to have_no_css(".delete")
  end

  it "hides unecessary sections and buttons for system themes" do
    theme.theme_fields.create!(
      name: "js",
      target_id: Theme.targets[:extra_js],
      value: "console.log('second test')",
    )
    yaml = <<~YAML
      enable_welcome_banner:
        default: true
        description: "Overrides the core `enable welcome banner` site setting"
    YAML
    theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!

    theme_page.visit(theme)
    expect(page).to have_css(".created-by")
    expect(page).to have_css(".export")
    expect(page).to have_css(".extra-files")
    expect(page).to have_css(".theme-settings")
    expect(page).to have_no_css(".system-theme-info")

    # Since we're only testing the one theme, we can stub the system? method
    # for every theme to return true.
    # This avoids needing to update the theme field data to point to a different theme id.
    allow_any_instance_of(Theme).to receive(:system?).and_return(true)

    theme_page.visit(theme)
    expect(page).to have_css(".system-theme-info")
    expect(page).to have_no_css(".created-by")
    expect(page).to have_no_css(".export")
    expect(page).to have_no_css(".extra-files")
    expect(page).to have_css(".theme-settings")
  end

  describe "when editing theme translations" do
    it "should allow admin to edit and save the theme translations" do
      theme.set_field(
        target: :translations,
        name: "en",
        value: { en: { group: { hello: "Hello there!" } } }.deep_stringify_keys.to_yaml,
      )

      theme.save!

      theme_page.visit(theme)

      theme_translations_settings_editor =
        PageObjects::Components::AdminThemeTranslationsSettingsEditor.new

      theme_translations_settings_editor.fill_in("Hello World")
      theme_translations_settings_editor.save

      theme_page.visit(theme)

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

      theme_page.visit(theme)

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

      theme_page.visit(theme)

      theme_translations_settings_editor =
        PageObjects::Components::AdminThemeTranslationsSettingsEditor.new

      expect(theme_translations_settings_editor.get_input_value).to have_content("Hello there!")

      theme_translations_picker = PageObjects::Components::SelectKit.new(".translation-selector")

      expect(theme_translations_picker.component).to have_content("English (US)")
    end
  end

  describe "when editing a theme's included components" do
    fab!(:component) { Fabricate(:theme, component: true, name: "Cool component 145") }

    it "can save the included components" do
      theme_page.visit(theme.id)
      theme_page.included_components_selector.expand
      theme_page.included_components_selector.select_row_by_index(0)
      theme_page.included_components_selector.collapse
      theme_page.relative_themes_save_button.click
      expect(theme_page).to have_reset_button_for_setting(".included-components-setting")
      expect(ChildTheme.exists?(parent_theme_id: theme.id, child_theme_id: component.id)).to eq(
        true,
      )
    end
  end

  context "when visting a component's page" do
    fab!(:component) { Fabricate(:theme, component: true, name: "Cool component 493") }

    it "has a link to the components page" do
      visit("/admin/customize/themes/#{component.id}")
      expect(theme_page).to have_back_button_to_components_page
    end

    it "allows to add component to all themes" do
      visit("/admin/customize/themes/#{component.id}")
      expect(page.find(".relative-theme-selector .formatted-selection").text).to eq(
        I18n.t("js.select_kit.default_header_text"),
      )
      theme_page.click_add_all_themes_button
      expect(page.find(".relative-theme-selector .formatted-selection").text).to eq(
        "#{theme.name}, Foundation, Horizon",
      )
    end
  end

  describe "editing theme site settings" do
    it "shows all themeable site settings and allows editing values" do
      theme_page.visit(theme.id)
      SiteSetting.themeable_site_settings.each do |setting_name|
        expect(theme_page).to have_theme_site_setting(setting_name)
      end
      theme_page.toggle_theme_site_setting("enable_welcome_banner")
      expect(theme_page).to have_overridden_theme_site_setting("enable_welcome_banner")
      expect(page).to have_content(
        I18n.t("admin_js.admin.customize.theme.theme_site_setting_saved"),
      )
      expect(
        ThemeSiteSetting.exists?(theme: theme, name: "enable_welcome_banner", value: "f"),
      ).to be_truthy
    end

    it "allows resetting themeable site setting values back to site setting default" do
      Fabricate(
        :theme_site_setting_with_service,
        theme: theme,
        name: "enable_welcome_banner",
        value: false,
      )
      theme_page.visit(theme.id)
      expect(theme_page).to have_overridden_theme_site_setting("enable_welcome_banner")
      theme_page.reset_overridden_theme_site_setting("enable_welcome_banner")
      expect(page).to have_content(
        I18n.t("admin_js.admin.customize.theme.theme_site_setting_saved"),
      )
      expect(
        ThemeSiteSetting.exists?(theme: theme, name: "enable_welcome_banner", value: "f"),
      ).to be_falsey
    end

    it "does not show the overridden indicator if the theme site setting value in the DB is the same as the default" do
      Fabricate(
        :theme_site_setting_with_service,
        theme: theme,
        name: "enable_welcome_banner",
        value: true,
      )
      theme_page.visit(theme.id)
      expect(theme_page).to have_theme_site_setting("enable_welcome_banner")
      expect(theme_page).to have_no_overridden_theme_site_setting("enable_welcome_banner")
    end

    it "alters the UI via MessageBus when a theme site setting changes" do
      SiteSetting.refresh!(refresh_site_settings: false, refresh_theme_site_settings: true)
      banner = PageObjects::Components::WelcomeBanner.new
      other_user = Fabricate(:user)
      other_user.user_option.update!(theme_ids: [theme.id])
      sign_in(other_user)
      visit("/")
      expect(banner).to be_visible

      using_session(:admin) do
        sign_in(admin)
        theme_page.visit(theme.id)
        theme_page.toggle_theme_site_setting("enable_welcome_banner")
      end

      expect(banner).to be_hidden
    end
  end
end
