# frozen_string_literal: true

describe "Patreon Oauth2" do
  let(:access_token) { "patreon_access_token_448" }
  let(:client_id) { "abcdef11223344" }
  let(:client_secret) { "adddcccdddd99922" }
  let(:temp_code) { "patreon_temp_code_544254" }

  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  def setup_patreon_emails_stub(email:, verified:)
    stub_request(:get, "https://api.patreon.com/oauth2/api/current_user").with(
      headers: {
        "Authorization" => "Bearer #{access_token}",
      },
    ).to_return(
      status: 200,
      body:
        JSON.dump(
          data: {
            id: "493290423324",
            attributes: {
              email: email,
              full_name: "Patron",
              is_email_verified: verified,
            },
          },
        ),
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  before do
    SiteSetting.patreon_creator_discourse_username = user2.username
    SiteSetting.patreon_login_enabled = true
    SiteSetting.patreon_client_id = client_id
    SiteSetting.patreon_client_secret = client_secret

    stub_request(:post, "https://api.patreon.com/oauth2/token").with(
      body:
        hash_including(
          "client_id" => client_id,
          "client_secret" => client_secret,
          "code" => temp_code,
          "grant_type" => "authorization_code",
          "redirect_uri" => "http://test.localhost/auth/patreon/callback",
        ),
    ).to_return(
      status: 200,
      body: Rack::Utils.build_query(access_token: access_token),
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
      },
    )
  end

  it "doesn't sign in the user if the email from patreon is not verified" do
    post "/auth/patreon"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://www.patreon.com/oauth2/authorize")

    setup_patreon_emails_stub(email: user1.email, verified: false)

    post "/auth/patreon/callback", params: { state: session["omniauth.state"], code: temp_code }
    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to be_blank
  end

  it "signs in the user if the email from patreon is verified" do
    post "/auth/patreon"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://www.patreon.com/oauth2/authorize")

    setup_patreon_emails_stub(email: user1.email, verified: true)

    post "/auth/patreon/callback", params: { state: session["omniauth.state"], code: temp_code }
    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to eq(user1.id)
  end
end
