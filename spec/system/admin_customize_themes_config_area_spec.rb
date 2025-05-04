# frozen_string_literal: true

describe "Admin Customize Themes Config Area Page", type: :system do
  fab!(:admin)

  let(:config_area) { PageObjects::Pages::AdminCustomizeThemesConfigArea.new }
  let(:install_modal) { PageObjects::Modals::InstallTheme.new }

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
end
