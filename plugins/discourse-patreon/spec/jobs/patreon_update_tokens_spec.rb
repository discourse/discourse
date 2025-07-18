# frozen_string_literal: true

require "rails_helper"
require_relative "../spec_helper"

RSpec.describe Jobs::PatreonUpdateTokens do
  before do
    SiteSetting.patreon_enabled = true

    stub_request(:post, "https://api.patreon.com/oauth2/token").with(
      body: {
        "client_id" => SiteSetting.patreon_client_id,
        "client_secret" => SiteSetting.patreon_client_secret,
        "grant_type" => "refresh_token",
        "refresh_token" => SiteSetting.patreon_creator_refresh_token,
      },
    ).to_return(status: 200, body: get_patreon_response("tokens.json"))
  end

  it "should update both access and refresh tokens from Patreon" do
    described_class.new.execute({})

    expect(SiteSetting.patreon_creator_access_token).to eq("ACCESS TOKEN")
    expect(SiteSetting.patreon_creator_refresh_token).to eq("REFRESH TOKEN")
  end
end
