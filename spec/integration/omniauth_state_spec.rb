# frozen_string_literal: true

describe "OAuth2 callback state validation" do
  before do
    SiteSetting.discord_client_id = "abcdef11223344"
    SiteSetting.discord_secret = "adddcccdddd99922"
    SiteSetting.enable_discord_logins = true
  end

  it "fails gracefully when the session has no state" do
    post "/auth/discord/callback", params: { state: "somestate", code: "somecode" }

    expect(response.status).to eq(302)
    expect(response.location).to eq("/auth/failure?message=csrf_detected&strategy=discord")
  end
end
