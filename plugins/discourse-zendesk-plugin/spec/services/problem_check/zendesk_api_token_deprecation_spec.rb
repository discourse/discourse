# frozen_string_literal: true

RSpec.describe ProblemCheck::ZendeskApiTokenDeprecation do
  describe "#call" do
    subject(:problem) { described_class.new.call }

    before do
      SiteSetting.zendesk_enabled = true
      SiteSetting.zendesk_jobs_email = "zendesk@example.com"
      SiteSetting.zendesk_jobs_api_token = "legacy-token"
    end

    it "returns a low-priority problem when the enabled plugin relies on API token authentication" do
      expect(problem).to be_present
      expect(problem.priority).to eq("low")
    end

    it "returns nil when OAuth credentials are configured" do
      SiteSetting.zendesk_oauth_client_id = "oauth-client-id"
      SiteSetting.zendesk_oauth_client_secret = "oauth-client-secret"

      expect(problem).to be_blank
    end

    it "returns nil when the plugin is disabled" do
      SiteSetting.zendesk_enabled = false

      expect(problem).to be_blank
    end

    it "returns nil when API token credentials are incomplete" do
      SiteSetting.zendesk_jobs_api_token = ""

      expect(problem).to be_blank
    end
  end
end
