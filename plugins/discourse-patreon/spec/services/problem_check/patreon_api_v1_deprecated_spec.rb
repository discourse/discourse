# frozen_string_literal: true

RSpec.describe ProblemCheck::PatreonApiV1Deprecated do
  before { SiteSetting.patreon_enabled = true }

  it "warns when using API v1" do
    SiteSetting.patreon_api_version = "1"
    expect(described_class.new.call).to be_present
  end

  it "does not warn when using API v2" do
    SiteSetting.patreon_api_version = "2"
    expect(described_class.new.call).to be_blank
  end
end
