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
    sign_in(admin)
  end

  it "warns the administrator to configure OAuth before API tokens stop working" do
    dashboard.visit

    expect(dashboard).to have_site_advice_problem(
      "The Discourse Zendesk plugin uses deprecated API token authentication. Configure the Zendesk OAuth client ID and client secret settings before April 30, 2027.",
    )
  end
end
