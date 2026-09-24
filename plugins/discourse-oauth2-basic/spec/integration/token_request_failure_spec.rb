# frozen_string_literal: true

describe "OAuth2 Basic token requests" do
  fab!(:user)

  before do
    SiteSetting.oauth2_client_id = "client"
    SiteSetting.oauth2_authorize_url = "https://id.example.com/authorize"
    SiteSetting.oauth2_token_url = "https://id.example.com/token"
    SiteSetting.oauth2_callback_user_id_path = "params.uid"
    SiteSetting.oauth2_callback_user_info_paths = "email:params.email"
    SiteSetting.oauth2_fetch_user_details = false
    SiteSetting.oauth2_email_verified = true
  end

  it "completes authentication with an empty client secret" do
    SiteSetting.oauth2_client_secret = ""
    SiteSetting.oauth2_enabled = true

    token_request =
      stub_request(:post, "https://id.example.com/token").with(
        headers: {
          "Authorization" => "Basic #{Base64.strict_encode64("client:")}",
        },
        body: hash_including("client_id" => "client", "client_secret" => "", "code" => "code"),
      ).to_return(
        status: 200,
        body: {
          access_token: "access-token",
          token_type: "Bearer",
          uid: "provider-uid",
          email: user.email,
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

    post "/auth/oauth2_basic"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://id.example.com/authorize?")

    post "/auth/oauth2_basic/callback", params: { state: session["omniauth.state"], code: "code" }

    expect(response.status).to eq(302)
    expect(session[:current_user_id]).to eq(user.id)
    expect(token_request).to have_been_requested.once
  end

  it "reports the plugin's own failure when the token request times out" do
    SiteSetting.oauth2_client_secret = "secret"
    SiteSetting.oauth2_enabled = true
    stub_request(:post, "https://id.example.com/token").to_timeout

    post "/auth/oauth2_basic"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://id.example.com/authorize?")

    post "/auth/oauth2_basic/callback", params: { state: session["omniauth.state"], code: "code" }
    expect(response.status).to eq(302)
    expect(response.location).to eq(
      "/auth/failure?message=oauth2_basic_request_failed&strategy=oauth2_basic",
    )
  end

  it "does not include provider error details in warning logs" do
    SiteSetting.oauth2_client_secret = "client-secret"
    SiteSetting.oauth2_enabled = true
    provider_error = "provider payload included access-token-value"
    messages = []
    allow(Rails.logger).to receive(:warn) { |message| messages << message }
    stub_request(:post, "https://id.example.com/token").to_raise(
      Faraday::ConnectionFailed.new(provider_error),
    )

    post "/auth/oauth2_basic"
    post "/auth/oauth2_basic/callback", params: { state: session["omniauth.state"], code: "code" }

    expect(response.location).to eq(
      "/auth/failure?message=oauth2_basic_request_failed&strategy=oauth2_basic",
    )
    expect(messages.join).to include("OAuth2 Basic: token request failed:")
    expect(messages.join).not_to include(provider_error, "access-token-value", "client-secret")
  end
end
