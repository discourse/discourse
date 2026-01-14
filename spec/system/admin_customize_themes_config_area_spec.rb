# frozen_string_literal: true

describe "Admin Customize Themes Config Area Page", type: :system do
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

    install_modal = config_area.click_install_button
    expect(install_modal.popular_options.first).to have_text("Air")
  end

  it "opens an install modal when coming from the install theme button on Meta" do
    config_area.visit(
      { "repoName" => "discourse-air", "repoUrl" => "https://github.com/discourse/discourse-air" },
    )

    expect(install_modal).to be_open
    expect(install_modal).to have_content("github.com/discourse/discourse-air")

    install_modal.close

    expect(page).to have_current_path("/admin/config/customize/themes")
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

    expect(page).to have_current_path(%r{/admin/customize/themes/\d+})
  end

  it "allows to edit and delete theme" do
    config_area.visit
    config_area.click_edit(theme)
    expect(page).to have_current_path("/admin/customize/themes/#{theme.id}")

    admin_customize_themes_page.click_delete
    admin_customize_themes_page.confirm_delete
    expect(page).to have_current_path("/admin/config/customize/themes")
  end

  it "has new look when edit theme is visited directly and can go back to themes" do
    visit("/admin/customize/themes/#{theme.id}")

    admin_customize_themes_page.click_back_to_themes

    expect(page).to have_current_path("/admin/config/customize/themes")
    expect(page).to have_content(
      I18n.t("admin_js.admin.config_areas.themes_and_components.themes.title"),
    )
  end
end
