# frozen_string_literal: true

describe "Admin Customize Themes" do
  fab!(:color_scheme) do
    Fabricate(:color_scheme, base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Light"])
  end
  fab!(:theme) { Fabricate(:theme, name: "Cool theme 1", user_selectable: true) }
  fab!(:admin) { Fabricate(:admin, locale: "en") }

  let(:theme_page) { PageObjects::Pages::AdminCustomizeThemes.new }
  let(:themes_page) { PageObjects::Pages::AdminCustomizeThemesConfigArea.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(admin) }

  describe "when visiting the page to customize a single theme" do
    it "keeps the sidebar navigation link active" do
      theme_page.visit(theme)
      expect(sidebar).to have_active_link("admin_themes_and_components")
    end

    it "allows admins to update the theme's light color scheme" do
      theme_page.visit(theme)

      color_scheme_settings =
        browser_root.locator(".theme-settings__light-color-scheme").filter(visible: true)

      expect(
        color_scheme_settings
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".submit-light-edit")
          .filter(visible: true),
      ).to have_count(0)
      expect(
        color_scheme_settings
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".cancel-light-edit")
          .filter(visible: true),
      ).to have_count(0)

      color_scheme_settings.locator(".color-palette-picker").filter(visible: true).click
      color_scheme_settings
        .locator(".color-palette-picker-row[data-value='#{color_scheme.id}']")
        .filter(visible: true)
        .click
      color_scheme_settings.locator(".submit-light-edit").filter(visible: true).click

      expect(color_scheme_settings.locator(".setting-value").filter(visible: true)).to contain_text(
        browser_text_pattern(color_scheme.name),
        useInnerText: true,
      )
      expect(
        color_scheme_settings
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".submit-light-edit")
          .filter(visible: true),
      ).to have_count(0)
      expect(
        color_scheme_settings
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".cancel-light-edit")
          .filter(visible: true),
      ).to have_count(0)

      expect(
        browser_root
          .get_by_role("link")
          .and(
            browser_root.locator(
              "[id=#{I18n.t("admin_js.admin.customize.theme.edit_colors").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.edit_colors").to_s.to_json}]",
            ).or(
              browser_root.get_by_role(
                "link",
                name: I18n.t("admin_js.admin.customize.theme.edit_colors"),
              ),
            ),
          )
          .and(
            browser_root.locator(
              "[href=#{"/admin/config/colors/#{color_scheme.id}".to_s.to_json}]",
            ),
          )
          .filter(visible: true),
      ).not_to have_count(0)
    end

    it "allows admins to update the theme's dark color scheme" do
      theme_page.visit(theme)

      color_scheme_settings =
        browser_root.locator(".theme-settings__dark-color-scheme").filter(visible: true)

      expect(
        color_scheme_settings
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".submit-dark-edit")
          .filter(visible: true),
      ).to have_count(0)
      expect(
        color_scheme_settings
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".cancel-dark-edit")
          .filter(visible: true),
      ).to have_count(0)

      color_scheme_settings.locator(".color-palette-picker").filter(visible: true).click
      color_scheme_settings
        .locator(".color-palette-picker-row[data-value='#{color_scheme.id}']")
        .filter(visible: true)
        .click
      color_scheme_settings.locator(".submit-dark-edit").filter(visible: true).click

      expect(color_scheme_settings.locator(".setting-value").filter(visible: true)).to contain_text(
        browser_text_pattern(color_scheme.name),
        useInnerText: true,
      )
      expect(
        color_scheme_settings
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".submit-dark-edit")
          .filter(visible: true),
      ).to have_count(0)
      expect(
        color_scheme_settings
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".cancel-dark-edit")
          .filter(visible: true),
      ).to have_count(0)

      expect(
        browser_root
          .get_by_role("link")
          .and(
            browser_root.locator(
              "[id=#{I18n.t("admin_js.admin.customize.theme.edit_colors").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.edit_colors").to_s.to_json}]",
            ).or(
              browser_root.get_by_role(
                "link",
                name: I18n.t("admin_js.admin.customize.theme.edit_colors"),
              ),
            ),
          )
          .and(
            browser_root.locator(
              "[href=#{"/admin/config/colors/#{color_scheme.id}".to_s.to_json}]",
            ),
          )
          .filter(visible: true),
      ).not_to have_count(0)
    end

    it "allows a theme to be deleted" do
      theme_page.visit(theme).click_delete_button_and_confirm

      expect(PageObjects::Components::Toasts.new).to have_success(
        I18n.t("admin_js.admin.customize.theme.delete_success", theme: theme.name),
      )

      expect(browser_page).to have_url("/admin/config/customize/themes")
      expect(themes_page).to have_no_theme(theme.name)
    end
  end

  describe "when editing a local theme" do
    it "The saved value is present in the editor" do
      theme.set_field(target: "common", name: "head_tag", value: "console.log('test')", type_id: 0)
      theme.save!

      browser_page
        .goto("/admin/customize/themes/#{theme.id}/common/head_tag/edit")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator(".ace_content").filter(visible: true)).to contain_text(
        browser_text_pattern("console.log('test')"),
        useInnerText: true,
      )
    end

    it "can edit the js field" do
      browser_page
        .goto("/admin/customize/themes/#{theme.id}/common/js/edit")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator(".ace_content").filter(visible: true)).to contain_text(
        browser_text_pattern("// Your code here"),
        useInnerText: true,
      )
      browser_root.locator(".ace_text-input").fill("console.log('test')\n")
      browser_root.locator(".save-theme").filter(visible: true).click

      expect(theme.theme_fields.find_by(target_id: Theme.targets[:extra_js])&.value).to start_with(
        "console.log('test')\n",
      )

      # Check content is loaded from db correctly
      theme
        .theme_fields
        .find_by(target_id: Theme.targets[:extra_js])
        .update!(value: "console.log('second test')")
      browser_page
        .goto("/admin/customize/themes/#{theme.id}/common/js/edit")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator(".ace_content").filter(visible: true)).to contain_text(
        browser_text_pattern("console.log('second test')"),
        useInnerText: true,
      )
    end

    it "shows the description of the field the admin switches to" do
      theme_page.visit_editor(theme)

      expect(theme_page).to have_editor_field_description("scss")

      theme_page.click_editor_field("head_tag")

      expect(theme_page).to have_editor_field_description("head_tag")
    end
  end

  it "cannot edit js, upload files or delete system themes" do
    theme.update_columns(id: -10)
    theme_page.visit(theme)
    expect(browser_root.locator(".system-theme-info").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator(".title button").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator(".title button svg").filter(visible: true)).to have_count(0)
    expect(browser_root.locator(".edit-code").filter(visible: true)).to have_count(0)
    expect(browser_root.locator("button.upload").filter(visible: true)).to have_count(0)
    expect(browser_root.locator(".delete").filter(visible: true)).to have_count(0)
  end

  it "hides unnecessary sections and buttons for system themes" do
    theme.set_field(
      target: :extra_js,
      name: "discourse/api-initializers/test.js",
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
    expect(browser_root.locator(".created-by").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator(".export").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator(".extra-files").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator(".theme-settings").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator(".system-theme-info").filter(visible: true)).to have_count(0)

    # Since we're only testing the one theme, we can stub the system? method
    # for every theme to return true.
    # This avoids needing to update the theme field data to point to a different theme id.
    allow_any_instance_of(Theme).to receive(:system?).and_return(true)

    theme_page.visit(theme)
    expect(browser_root.locator(".system-theme-info").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator(".created-by").filter(visible: true)).to have_count(0)
    expect(browser_root.locator(".export").filter(visible: true)).to have_count(0)
    expect(browser_root.locator(".extra-files").filter(visible: true)).to have_count(0)
    expect(browser_root.locator(".theme-settings").filter(visible: true)).not_to have_count(0)
  end

  it "shows both JS and SCSS extra files with canonical paths" do
    theme.set_field(
      target: :extra_js,
      name: "discourse/api-initializers/canvas.js",
      value: "console.log('extra js')",
    )
    theme.set_field(target: :extra_scss, name: "properties", value: ".custom { color: red; }")
    theme.save!

    theme_page.visit(theme)

    extra_files = browser_root.locator(".extra-files").filter(visible: true)
    extra_files.locator("summary").filter(visible: true).click

    expect(extra_files).to contain_text(
      browser_text_pattern("javascripts/discourse/api-initializers/canvas.js"),
      useInnerText: true,
    )
    expect(extra_files).to contain_text(
      browser_text_pattern("stylesheets/properties.scss"),
      useInnerText: true,
    )
  end

  describe "when editing theme translations" do
    it "allows admins to edit and save theme translations" do
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

      expect(theme_translations_settings_editor.get_input_value).to include("Hello World")
    end

    it "allows admins to edit and save theme translations in other languages" do
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
      expect(theme_translations_settings_editor.get_input_value).to include("Hello there!")

      theme_translations_picker = PageObjects::Components::SelectKit.new(".translation-selector")
      theme_translations_picker.select_row_by_value("fr")

      expect(browser_root.locator(".translations").filter(visible: true)).not_to have_count(0)

      expect(theme_translations_settings_editor.get_input_value).to include("Bonjour!")

      theme_translations_settings_editor.fill_in("Hello World in French")
      theme_translations_settings_editor.save
    end

    it "uses translations matching the current user's locale" do
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

      expect(theme_translations_settings_editor.get_input_value).to include("Hello there!")

      theme_translations_picker = PageObjects::Components::SelectKit.new(".translation-selector")

      expect(theme_translations_picker.component).to contain_text("English")
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

  context "when visiting a component's page" do
    fab!(:component) { Fabricate(:theme, component: true, name: "Cool component 493") }

    it "has a link to the components page" do
      browser_page
        .goto("/admin/customize/themes/#{component.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(theme_page).to have_back_button_to_components_page
    end

    it "allows to add component to all themes" do
      browser_page
        .goto("/admin/customize/themes/#{component.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(
        browser_root
          .locator(".relative-theme-selector .formatted-selection")
          .filter(visible: true)
          .inner_text
          .strip,
      ).to eq(I18n.t("js.select_kit.default_header_text"))
      theme_page.click_add_all_themes_button
      expect(
        browser_root
          .locator(".relative-theme-selector .formatted-selection")
          .filter(visible: true)
          .inner_text
          .strip,
      ).to eq("#{theme.name}, Foundation, Horizon")
    end

    describe "when leaving the page" do
      let(:unassigned_warning) { I18n.t("admin_js.admin.customize.theme.unsaved_parent_themes") }

      it "warns when the component is enabled but not used by any themes" do
        theme_page.visit(component)
        theme_page.click_back_to_components
        expect(dialog).to have_displayed_content(unassigned_warning)

        dialog.click_no
        expect(browser_page).to have_url("/admin/customize/themes/#{component.id}")
        expect(
          browser_root.locator(".parent-themes-setting .select-kit-header:focus").filter(
            visible: true,
          ),
        ).not_to have_count(0)

        theme_page.click_back_to_components
        expect(dialog).to have_displayed_content(unassigned_warning)

        dialog.click_yes
        expect(browser_page).to have_url("/admin/config/customize/components")
      end

      it "doesn't warn after the admin saves an empty theme selection" do
        theme.add_relative_theme!(:child, component)

        theme_page.visit(component)
        theme_page.parent_themes_selector.expand
        theme_page.parent_themes_selector.unselect_by_name(theme.name)
        theme_page.parent_themes_selector.collapse
        browser_root
          .locator(".parent-themes-setting .setting-controls .ok")
          .filter(visible: true)
          .click
        expect(
          browser_root.locator(".parent-themes-setting .setting-controls").filter(visible: true),
        ).to have_count(0)
        expect(component.reload.parent_themes).to RSpecPredicates.be_empty

        theme_page.click_back_to_components

        expect(browser_page).to have_url("/admin/config/customize/components")
        expect(dialog).to be_closed
      end

      it "doesn't warn when the component is disabled" do
        component.update!(enabled: false)

        theme_page.visit(component)
        theme_page.click_back_to_components

        expect(browser_page).to have_url("/admin/config/customize/components")
        expect(dialog).to be_closed
      end

      it "doesn't warn when the component is used by a theme" do
        theme.add_relative_theme!(:child, component)

        theme_page.visit(component)
        theme_page.click_back_to_components

        expect(browser_page).to have_url("/admin/config/customize/components")
        expect(dialog).to be_closed
      end

      it "doesn't warn when opening the component's code editor" do
        theme_page.visit(component)
        theme_page.click_edit_code

        expect(browser_page).to have_url(%r{/#{component.id}/common/scss/edit})
        expect(dialog).to be_closed
      end

      context "with unsaved setting changes" do
        let(:unsaved_warning) { I18n.t("admin_js.admin.customize.theme.unsaved_changes_alert") }

        before do
          theme.add_relative_theme!(:child, component)
          component.set_field(target: :settings, name: "yaml", value: "greeting: hello")
          component.save!
        end

        it "lets the admin stay on the page" do
          theme_page.visit(component).fill_in_setting("greeting", "howdy")
          theme_page.click_back_to_components
          expect(dialog).to have_displayed_content(unsaved_warning)

          dialog.click_no
          expect(browser_page).to have_url("/admin/customize/themes/#{component.id}")
          expect(theme_page).to have_setting_value("greeting", "howdy")
        end

        it "discards the changes when leaving" do
          theme_page.visit(component).fill_in_setting("greeting", "howdy")
          theme_page.click_back_to_components
          expect(dialog).to have_displayed_content(unsaved_warning)

          dialog.click_danger
          expect(browser_page).to have_url("/admin/config/customize/components")

          browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(theme_page).to have_setting_value("greeting", "hello")
        end
      end

      it "warns about an unsaved theme selection instead of the component being unused" do
        theme_page.visit(component)
        theme_page.parent_themes_selector.expand
        theme_page.parent_themes_selector.select_row_by_index(0)
        theme_page.parent_themes_selector.collapse
        theme_page.click_back_to_components

        expect(dialog).to have_displayed_content(
          I18n.t("admin_js.admin.customize.theme.unsaved_changes_alert"),
        )
      end

      it "doesn't warn after deleting the component" do
        theme_page.visit(component)
        theme_page.click_delete_button_and_confirm

        expect(browser_page).to have_url("/admin/config/customize/themes")
        expect(dialog).to be_closed
      end
    end
  end

  describe "changing theme source" do
    fab!(:git_theme) do
      theme = Fabricate(:theme, name: "Git Theme")
      theme.remote_theme =
        RemoteTheme.create!(
          remote_url: "https://github.com/discourse/example-theme.git",
          branch: "main",
          local_version: "abc123",
          remote_version: "abc123",
          commits_behind: 0,
        )
      theme.save!
      theme
    end

    it "opens the change source modal with pre-filled values, and allows submitting" do
      # Stub the git fetch so the update succeeds without hitting a real remote.
      allow_any_instance_of(RemoteTheme).to receive(:update_from_remote) do |remote_theme|
        remote_theme.save!
      end

      new_url = "https://github.com/discourse/some-other-theme.git"

      theme_page.visit(git_theme)
      browser_root
        .locator("button")
        .filter(visible: true)
        .filter(
          hasText:
            browser_text_pattern(I18n.t("admin_js.admin.customize.theme.change_source.button")),
        )
        .click

      expect(
        browser_root.locator(".admin-change-theme-source-modal").filter(visible: true),
      ).not_to have_count(0)
      expect(
        browser_root
          .locator(".admin-change-theme-source-modal input.repo-url")
          .filter(visible: true)
          .input_value,
      ).to eq("https://github.com/discourse/example-theme.git")
      expect(
        browser_root
          .locator(".admin-change-theme-source-modal input.branch")
          .filter(visible: true)
          .input_value,
      ).to eq("main")

      browser_root
        .locator(".admin-change-theme-source-modal input.repo-url")
        .filter(visible: true)
        .fill(new_url)
      browser_root
        .locator(".admin-change-theme-source-modal button.btn-primary")
        .filter(visible: true)
        .click

      expect(
        browser_root.locator(".admin-change-theme-source-modal").filter(visible: true),
      ).to have_count(0)
      expect(git_theme.reload.remote_theme.remote_url).to eq(new_url)
    end

    it "does not show the change source button for local themes" do
      theme_page.visit(theme)
      expect(
        browser_root
          .get_by_role("button")
          .and(
            browser_root.locator(
              "[id=#{I18n.t("admin_js.admin.customize.theme.change_source.button").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.change_source.button").to_s.to_json}]",
            ).or(
              browser_root.get_by_role(
                "button",
                name: I18n.t("admin_js.admin.customize.theme.change_source.button"),
              ),
            ),
          )
          .filter(visible: true),
      ).to have_count(0)
    end
  end

  describe "editing an icon type theme setting" do
    let(:icon_picker) do
      PageObjects::Components::DIconGridPicker.new(".setting[data-setting='icon_setting']")
    end

    before do
      SiteSetting.svg_icon_subset = "gamepad"

      theme.set_field(
        target: :settings,
        name: "yaml",
        value: "icon_setting:\n  type: icon\n  default: heart\n",
      )
      theme.save!
    end

    it "allows admin to pick an icon from the dropdown and save it" do
      theme_page.visit(theme)

      expect(icon_picker).to have_selected_icon("heart")

      icon_picker.expand
      icon_picker.filter("gamepad")
      icon_picker.select_icon("gamepad")

      browser_root
        .locator(".setting[data-setting='icon_setting'] .setting-controls__ok")
        .filter(visible: true)
        .click

      expect(
        browser_root.locator(".setting[data-setting='icon_setting'] .setting-controls__ok").filter(
          visible: true,
        ),
      ).to have_count(0)
      expect(theme.reload.settings[:icon_setting].value).to eq("gamepad")
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
      expect(browser_content).to contain_text(
        browser_text_pattern(I18n.t("admin_js.admin.customize.theme.theme_site_setting_saved")),
        useInnerText: true,
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
      expect(browser_content).to contain_text(
        browser_text_pattern(I18n.t("admin_js.admin.customize.theme.theme_site_setting_saved")),
        useInnerText: true,
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

      # `Theme.user_theme_ids` is cached across examples; a stale entry makes
      # the user resolve the wrong theme.
      Theme.clear_cache!

      sign_in(other_user)
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(banner).to RSpecPredicates.be_visible

      # A sanity check.
      expect(
        browser_root.locator("meta[name=discourse_theme_id][content='#{theme.id}']"),
      ).not_to have_count(0)

      # Wait for the `/client_settings` subscription's first poll to finish.
      try_until_success do
        expect(
          browser_page.evaluate(
            "function(arguments) { return window.MessageBus.callbacks.find((c) => c.channel === '/client_settings')?.last_id ?? -1 }",
            arg: [],
          ),
        ).to be >= 0
      end

      using_browser_session(:admin) do
        sign_in(admin)
        theme_page.visit(theme.id)
        theme_page.toggle_theme_site_setting("enable_welcome_banner")
      end

      try_until_success(reason: "Relies on MessageBus updates") do
        expect(banner).to RSpecPredicates.be_hidden
      end
    end
  end
end
