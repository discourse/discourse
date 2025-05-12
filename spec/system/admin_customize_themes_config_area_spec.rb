# frozen_string_literal: true

describe "Admin Customize Themes Config Area Page", type: :system do
  fab!(:admin)
  fab!(:theme) { Theme.where(component: false).first }
  fab!(:theme_2) { Fabricate(:theme, name: "Second theme") }

  let(:config_area) { PageObjects::Pages::AdminCustomizeThemesConfigArea.new }
  let(:install_modal) { PageObjects::Modals::InstallTheme.new }
  let(:admin_customize_themes_page) { PageObjects::Pages::AdminCustomizeThemes.new }

  before { sign_in(admin) }

  it "has a special card for installing new themes" do
    config_area.visit

    expect(config_area.install_card).to have_text(
      I18n.t("admin_js.admin.config_areas.themes_and_components.themes.new_theme"),
    )

    config_area.install_card.find(".btn-primary").click
    expect(install_modal).to be_open
    expect(install_modal.popular_options.first).to have_text("Air")
  end

  it "allows to mark theme as active" do
    config_area.visit
    expect(config_area).to have_badge(theme, "--active")
    expect(config_area).to have_no_badge(theme_2, "--active")
    config_area.mark_as_active(theme_2)
    expect(config_area).to have_badge(theme_2, "--active")
    expect(config_area).to have_no_badge(theme, "--active")
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
    expect(page).to have_css(".back-to-themes-and-components")
    expect(admin_customize_themes_page).to have_back_button_to_themes_page
    admin_customize_themes_page.click_back_to_themes
    expect(page).to have_current_path("/admin/config/customize/themes")
  end
end
