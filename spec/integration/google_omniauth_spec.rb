# frozen_string_literal: true

describe "Google Oauth2" do
  let(:access_token) { "google_access_token_123" }
  let(:client_id) { "123456789.apps.googleusercontent.com" }
  let(:client_secret) { "googleclientsecret" }
  let(:temp_code) { "google_temp_code_544254" }
  let(:attacker_state) { "attacker-predetermined-state" }

  fab!(:attacker, :user)

  before do
    SiteSetting.google_oauth2_client_id = client_id
    SiteSetting.google_oauth2_client_secret = client_secret
    SiteSetting.enable_google_oauth2_logins = true

    # Common SSO configuration in which the request phase is reachable via a
    # cross-site GET (e.g. one-click login). This does not grant the attacker
    # any authority; it only makes the request phase navigable.
    SiteSetting.auth_require_interaction = false

    stub_request(:post, "https://oauth2.googleapis.com/token").to_return(
      status: 200,
      body:
        Rack::Utils.build_query(access_token: access_token, expires_in: 3600, token_type: "Bearer"),
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
      },
    )

    stub_request(:get, "https://www.googleapis.com/oauth2/v3/userinfo").with(
      headers: {
        "Authorization" => "Bearer #{access_token}",
      },
    ).to_return(
      status: 200,
      body:
        JSON.dump(sub: "2435678", email: attacker.email, email_verified: true, name: "Attacker"),
      headers: {
        "Content-Type" => "application/json",
      },
    )

    stub_request(:post, "https://www.googleapis.com/oauth2/v3/tokeninfo").to_return(
      status: 200,
      body: JSON.dump(aud: client_id, scope: "openid email profile"),
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  it "ignores a request-supplied state and uses a generated CSRF nonce" do
    get "/auth/google_oauth2", params: { state: attacker_state }
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://accounts.google.com/o/oauth2/auth?")

    redirect_state = Rack::Utils.parse_query(URI(response.location).query)["state"]
    expect(session["omniauth.state"]).to be_present
    expect(session["omniauth.state"]).not_to eq(attacker_state)
    expect(redirect_state).not_to eq(attacker_state)
  end

  it "rejects a callback whose state the attacker predetermined in the request params" do
    get "/auth/google_oauth2", params: { state: attacker_state }
    expect(response.status).to eq(302)

    post "/auth/google_oauth2/callback", params: { state: attacker_state, code: temp_code }

    expect(response).to redirect_to("/auth/failure?message=csrf_detected&strategy=google_oauth2")
    expect(session[:current_user_id]).to be_blank
  end
end
