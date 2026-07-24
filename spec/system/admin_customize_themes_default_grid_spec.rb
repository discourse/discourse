# frozen_string_literal: true

describe "Admin Customize Themes default grid" do
  fab!(:admin)
  fab!(:foundation_theme) { Theme.foundation_theme }
  fab!(:horizon_theme) { Theme.horizon_theme }

  let(:config_area) { PageObjects::Pages::AdminCustomizeThemesConfigArea.new }

  before { sign_in(admin) }

  it "shows an install themes CTA when only the default themes are installed" do
    config_area.visit

    expect(config_area).to have_themes(["Foundation", "Horizon", "Install more themes"])
    expect(config_area).to have_theme_cards(count: 3)
    expect(config_area).to have_install_more_themes_card

    install_modal = config_area.click_install_more_themes

    expect(install_modal).to be_open
    expect(install_modal.popular_options.first).to have_text("Graceful")
  end
end
