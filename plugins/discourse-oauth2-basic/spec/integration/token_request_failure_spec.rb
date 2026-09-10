# frozen_string_literal: true

describe "OAuth2 Basic token request failures" do
  before do
    SiteSetting.oauth2_enabled = true
    SiteSetting.oauth2_client_id = "client"
    SiteSetting.oauth2_client_secret = "secret"
    SiteSetting.oauth2_authorize_url = "https://id.example.com/authorize"
    SiteSetting.oauth2_token_url = "https://id.example.com/token"
    stub_request(:post, "https://id.example.com/token").to_timeout
  end

  it "reports the plugin's own failure when the token request times out" do
    post "/auth/oauth2_basic"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://id.example.com/authorize?")

    post "/auth/oauth2_basic/callback", params: { state: session["omniauth.state"], code: "code" }
    expect(response.status).to eq(302)
    expect(response.location).to eq(
      "/auth/failure?message=oauth2_basic_request_failed&strategy=oauth2_basic",
    )
  end
end
