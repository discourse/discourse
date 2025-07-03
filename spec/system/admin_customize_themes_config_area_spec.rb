# frozen_string_literal: true

describe "Admin Customize Themes Config Area Page", type: :system do
  fab!(:admin)
  fab!(:theme) { Fabricate(:theme, name: "First theme") }
  fab!(:default_theme) { Theme.where(component: false, name: "Default").first }
  fab!(:foundation_theme) { Theme.foundation_theme }
  fab!(:theme_child_theme) do
    Fabricate(:theme, name: "Child theme", component: true, enabled: true, parent_themes: [theme])
  end
  fab!(:theme_2) { Fabricate(:theme, name: "Second theme") }

  let(:config_area) { PageObjects::Pages::AdminCustomizeThemesConfigArea.new }
  let(:install_modal) { PageObjects::Modals::InstallTheme.new }
  let(:admin_customize_themes_page) { PageObjects::Pages::AdminCustomizeThemes.new }

  before do
    SiteSetting.experimental_system_themes = "foundation|horizon"
    sign_in(admin)
  end

  it "has an install button in the subheader" do
    config_area.visit

    config_area.subheader.find(".btn-primary").click
    expect(install_modal).to be_open
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

  it "allows to mark theme as active" do
    config_area.visit
    expect(config_area).to have_badge(default_theme, "--active")
    expect(config_area).to have_no_badge(theme_2, "--active")
    config_area.mark_as_active(theme_2)
    expect(config_area).to have_badge(theme_2, "--active")
    expect(config_area).to have_no_badge(foundation_theme, "--active")
    expect(config_area).to have_themes(
      ["Second theme", "Horizon", "Foundation", "Default", "First theme"],
    )
  end

  it "allows to make theme selectable by users" do
    config_area.visit
    expect(config_area).to have_no_badge(theme, "--selectable")
    config_area.toggle_selectable(theme)
    expect(config_area).to have_badge(theme, "--selectable")
    config_area.toggle_selectable(theme)
    expect(config_area).to have_no_badge(theme, "--selectable")
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

  it "allows controlling visibility of system themes with experimental_system_themes setting" do
    SiteSetting.experimental_system_themes = ""
    config_area.visit
    expect(config_area).to have_themes(["Default", "First theme", "Second theme"])

    SiteSetting.experimental_system_themes = "foundation"
    config_area.visit
    expect(config_area).to have_themes(["Default", "Foundation", "First theme", "Second theme"])

    SiteSetting.experimental_system_themes = "foundation|horizon"
    config_area.visit
    expect(config_area).to have_themes(
      ["Default", "Horizon", "Foundation", "First theme", "Second theme"],
    )
  end
end
