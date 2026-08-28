# frozen_string_literal: true

RSpec.describe "Configure Zendesk OAuth" do
  fab!(:admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "warns the administrator to configure OAuth before API tokens stop working" do
    SiteSetting.dashboard_improvements = true
    SiteSetting.zendesk_enabled = true
    SiteSetting.zendesk_jobs_email = "zendesk@example.com"
    SiteSetting.zendesk_jobs_api_token = "legacy-token"
    Fabricate(:admin_notice, identifier: "host_names")

    dashboard.visit
    dashboard.refresh_site_advice

    expect(dashboard).to have_site_advice_problem(
      "The Discourse Zendesk plugin uses deprecated API token authentication. Configure the Zendesk OAuth client ID and client secret settings before April 30, 2027.",
    )
  end

  it "shows the administrator how to configure OAuth client credentials" do
    settings_page.visit_filtered_plugin_setting("zendesk_oauth")

    expect(settings_page).to have_setting_description(
      "zendesk_oauth_client_id",
      "The unique client ID provided by your Zendesk application, used for the authentication process.",
    )
    expect(settings_page).to have_setting_description(
      "zendesk_oauth_client_secret",
      "Client secret of your Zendesk application.",
    )
    expect(settings_page).to have_secret_setting_input("zendesk_oauth_client_secret")
  end
end
