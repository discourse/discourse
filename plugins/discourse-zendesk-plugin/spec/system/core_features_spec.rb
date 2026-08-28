# frozen_string_literal: true

RSpec.describe "Core features" do
  before { enable_current_plugin }

  it_behaves_like "having working core features"
end

RSpec.describe "Zendesk API token deprecation warning" do
  fab!(:admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }

  before do
    enable_current_plugin
    SiteSetting.dashboard_improvements = true
    SiteSetting.zendesk_enabled = true
    SiteSetting.zendesk_jobs_email = "zendesk@example.com"
    SiteSetting.zendesk_jobs_api_token = "legacy-token"
    Fabricate(:admin_notice, identifier: "host_names")
    sign_in(admin)
  end

  it "warns the administrator to configure OAuth before API tokens stop working" do
    dashboard.visit
    dashboard.refresh_site_advice

    expect(dashboard).to have_site_advice_problem(
      "The Discourse Zendesk plugin uses deprecated API token authentication. Configure the Zendesk OAuth client ID and client secret settings before April 30, 2027.",
    )
  end
end

RSpec.describe "Zendesk OAuth settings" do
  fab!(:admin)

  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "explains how to configure the OAuth client credentials" do
    settings_page.visit_filtered_plugin_setting("zendesk_oauth")

    client_id_setting = settings_page.find_setting("zendesk_oauth_client_id")
    expect(client_id_setting).to have_text("confidential Zendesk OAuth client")
    expect(client_id_setting).to have_text(
      "tickets:read, tickets:write, users:read, and users:write",
    )

    client_secret_setting = settings_page.find_setting("zendesk_oauth_client_secret")
    expect(client_secret_setting).to have_text("secret shown once")
    expect(settings_page.secret_setting_input("zendesk_oauth_client_secret")).to be_present
  end
end
