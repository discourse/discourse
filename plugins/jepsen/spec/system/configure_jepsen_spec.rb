# frozen_string_literal: true

RSpec.describe "Configure Jepsen" do
  fab!(:admin)

  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  before { sign_in(admin) }

  it "lets an admin disable Jepsen from the Plugins settings" do
    settings_page.visit_filtered_plugin_setting("jepsen_enabled")

    expect(settings_page).to have_setting("jepsen_enabled")
    expect(page).to have_content("Jepsen enabled")
    expect(page).to have_content(I18n.t("site_settings.jepsen_enabled"))
    expect(settings_page.bool_setting_checkbox("jepsen_enabled")).to be_checked

    settings_page.toggle_bool_setting("jepsen_enabled")

    page.refresh
    expect(settings_page.bool_setting_checkbox("jepsen_enabled")).not_to be_checked
  end
end
