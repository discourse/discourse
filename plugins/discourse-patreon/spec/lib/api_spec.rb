# frozen_string_literal: true

RSpec.describe Patreon::Api do
  def stub_url(status, url)
    content = { status: status, headers: { "Content-Type" => "application/json" }, body: "{}" }
    stub_request(:get, url).to_return(content)
  end

  before { SiteSetting.stubs(patreon_enabled: true) }

  context "with API v1" do
    let(:url) do
      "https://api.patreon.com/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges&page%5Bcount%5D=100"
    end

    before { SiteSetting.patreon_api_version = "1" }

    it "should add admin warning message for invalid api response" do
      stub_url(401, url)
      described_class.campaign_data
      expect(ProblemCheckTracker[:access_token_invalid].blips).to eq(1)
    end

    it "should add warning log" do
      stub_url(500, url)
      Discourse.expects(:warn_exception).once
      described_class.campaign_data
    end
  end

  context "with API v2" do
    let(:url) do
      "https://www.patreon.com/api/oauth2/v2/campaigns?include=tiers,creator&fields%5Bcampaign%5D=created_at,name,patron_count&fields%5Btier%5D=title,amount_cents,created_at"
    end

    before { SiteSetting.patreon_api_version = "2" }

    it "should add admin warning message for invalid api response" do
      stub_url(401, url)
      described_class.campaign_data
      expect(ProblemCheckTracker[:access_token_invalid].blips).to eq(1)
      expect(AdminNotice.find_by(identifier: :access_token_invalid).message).to eq(
        I18n.t("dashboard.problem.access_token_invalid", base_path: Discourse.base_path),
      )
    end

    it "should not add admin warning message for valid api response" do
      stub_url(200, url)
      expect(ProblemCheckTracker[:access_token_invalid].blips).to eq(0)
    end

    it "should add warning log" do
      stub_url(500, url)
      Discourse.expects(:warn_exception).once
      expect(described_class.campaign_data).to eq(error: I18n.t(described_class::INVALID_RESPONSE))
    end
  end
end
