# frozen_string_literal: true

describe "Admin Customize Themes Config Area Page" do
  fab!(:admin)
  fab!(:theme) { Fabricate(:theme, name: "First theme") }
  fab!(:foundation_theme) { Theme.foundation_theme }
  fab!(:horizon_theme) { Theme.horizon_theme }
  fab!(:theme_child_theme) do
    Fabricate(:theme, name: "Child theme", component: true, enabled: true, parent_themes: [theme])
  end
  fab!(:theme_2) { Fabricate(:theme, name: "Second theme") }

  let(:config_area) { PageObjects::Pages::AdminCustomizeThemesConfigArea.new }
  let(:install_modal) { PageObjects::Modals::InstallTheme.new }
  let(:admin_customize_themes_page) { PageObjects::Pages::AdminCustomizeThemes.new }

  before { sign_in(admin) }

  it "has an install button in the subheader" do
    config_area.visit

    screenshot_marker(label: "admin-themes", only: "desktop")

    install_modal = config_area.click_install_button
    expect(install_modal.popular_options.first).to contain_text(
      browser_text_pattern("Graceful"),
      useInnerText: true,
    )
  end

  it "opens an install modal when coming from the install theme button on Meta" do
    config_area.visit(
      { "repoName" => "graceful", "repoUrl" => "https://github.com/discourse/graceful" },
    )

    expect(install_modal).to be_open
    expect(install_modal).to have_displayed_content("github.com/discourse/graceful")

    install_modal.close

    expect(browser_page).to have_url("/admin/config/customize/themes")
  end

  it "allows to delete not system and not default theme" do
    theme.set_default!
    config_area.visit

    expect(config_area).to have_disabled_delete_button(theme)

    expect(config_area).to have_disabled_delete_button(horizon_theme)

    expect(config_area).to have_themes(["First theme", "Horizon", "Foundation", "Second theme"])
    config_area.delete_theme(theme_2)
    expect(config_area).to have_no_theme("Second theme")
  end

  it "allows to mark theme as default" do
    config_area.visit
    expect(config_area).to have_default_badge(foundation_theme)
    expect(config_area).to have_no_default_badge(theme_2)

    config_area.mark_as_default(theme_2)

    expect(config_area).to have_default_badge(theme_2)
    expect(config_area).to have_no_default_badge(foundation_theme)
  end

  it "allows to make theme selectable by users" do
    config_area.visit
    expect(config_area).to have_no_badge(theme, "--selectable")
    config_area.toggle_selectable(theme)
    expect(config_area).to have_badge(theme, "--selectable")
    config_area.toggle_selectable(theme)
    expect(config_area).to have_no_badge(theme, "--selectable")
  end

  it "allows a theme to be created" do
    config_area.visit.click_install_button.create_new_theme(name: "some new theme")

    expect(PageObjects::Components::Toasts.new).to have_success(
      I18n.t("admin_js.admin.customize.theme.install_success", theme: "some new theme"),
    )

    expect(browser_page).to have_url(%r{/admin/customize/themes/\d+})
  end

  it "allows to edit and delete theme" do
    config_area.visit
    config_area.click_edit(theme)
    expect(browser_page).to have_url("/admin/customize/themes/#{theme.id}")

    admin_customize_themes_page.click_delete
    admin_customize_themes_page.confirm_delete
    expect(browser_page).to have_url("/admin/config/customize/themes")
  end

  it "has new look when edit theme is visited directly and can go back to themes" do
    browser_page
      .goto("/admin/customize/themes/#{theme.id}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    admin_customize_themes_page.click_back_to_themes

    expect(browser_page).to have_url("/admin/config/customize/themes")
    expect(browser_content).to contain_text(
      browser_text_pattern(
        I18n.t("admin_js.admin.config_areas.themes_and_components.themes.title"),
      ),
      useInnerText: true,
    )
  end

  describe "screenshot toggle" do
    fab!(:light_upload, :image_upload)
    fab!(:dark_upload, :image_upload)
    fab!(:theme_with_screenshots) do
      Fabricate(
        :theme,
        name: "Theme with screenshots",
        theme_fields: [
          ThemeField.new(
            target_id: Theme.targets[:common],
            name: "screenshot_light",
            type_id: ThemeField.types[:theme_screenshot_upload_var],
            upload_id: light_upload.id,
            value: "",
          ),
          ThemeField.new(
            target_id: Theme.targets[:common],
            name: "screenshot_dark",
            type_id: ThemeField.types[:theme_screenshot_upload_var],
            upload_id: dark_upload.id,
            value: "",
          ),
        ],
      )
    end

    it "allows toggling between light and dark screenshots" do
      config_area.visit

      light_src =
        config_area.screenshot_image(theme_with_screenshots).evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "src",
        )
      expect(light_src).to include(light_upload.url)

      expect(config_area).to have_screenshot_with_icon(theme_with_screenshots, "moon")

      config_area.click_screenshot_toggle(theme_with_screenshots)

      expect(
        config_area.screenshot_image(theme_with_screenshots).evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "src",
        ),
      ).to include(dark_upload.url)
      expect(
        config_area.screenshot_image(theme_with_screenshots).evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "src",
        ),
      ).not_to eq(light_src)

      expect(config_area).to have_screenshot_with_icon(theme_with_screenshots, "sun")

      config_area.click_screenshot_toggle(theme_with_screenshots)

      expect(
        config_area.screenshot_image(theme_with_screenshots).evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "src",
        ),
      ).to include(light_src)

      config_area.visit

      expect(config_area).to have_no_screenshot_toggle_button(theme)
    end
  end
end
