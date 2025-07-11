# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::Patreon::Api do
  let(:url) do
    "https://api.patreon.com/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges&page%5Bcount%5D=100"
  end

  def stub(status)
    content = { status: status, headers: { "Content-Type" => "application/json" }, body: "{}" }

    stub_request(:get, url).to_return(content)
  end

  before { SiteSetting.stubs(patreon_enabled: true) }

  it "should add admin warning message for invalid api response" do
    stub(401)

    described_class.get(url)

    expect(ProblemCheckTracker[:access_token_invalid].blips).to eq(1)
    expect(AdminNotice.find_by(identifier: :access_token_invalid).message).to eq(
      I18n.t("dashboard.problem.access_token_invalid", base_path: Discourse.base_path),
    )
  end

  it "should not add admin warning message for valid api response" do
    stub(200)

    expect(ProblemCheckTracker[:access_token_invalid].blips).to eq(0)
  end

  it "should add warning log" do
    stub(500)

    Discourse.expects(:warn_exception).once
    expect(described_class.get(url)).to eq(error: I18n.t(described_class::INVALID_RESPONSE))
  end
end
