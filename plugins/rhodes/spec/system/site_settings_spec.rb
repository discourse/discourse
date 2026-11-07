# frozen_string_literal: true

RSpec.describe "Rhodes site settings" do
  fab!(:admin)

  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  it "shows the enabled setting in the Plugins group and lets an admin disable it" do
    sign_in(admin)
    settings_page.visit_filtered_plugin_setting("rhodes_enabled")

    expect(settings_page.find_setting("rhodes_enabled")).to have_content("Enable Rhodes.")
    expect(settings_page.bool_setting_checkbox("rhodes_enabled")).to be_checked

    settings_page.toggle_bool_setting("rhodes_enabled")
    page.refresh

    expect(settings_page.bool_setting_checkbox("rhodes_enabled")).not_to be_checked
    expect(SiteSetting.rhodes_enabled).to eq(false)
  end
end
