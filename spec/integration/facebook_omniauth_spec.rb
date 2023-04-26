# frozen_string_literal: true

describe "Facebook OAuth2" do
  let(:access_token) { "facebook_access_token_448" }
  let(:app_id) { "432489234823984" }
  let(:app_secret) { "adddcccdddd99922" }
  let(:temp_code) { "facebook_temp_code_544254" }
  let(:appsecret_proof) do
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, app_secret, access_token)
  end

  fab!(:user1) { Fabricate(:user) }

  def setup_facebook_email_stub(email:)
    body = {
      id: "4923489839597234",
      name: "Robot Lizard",
      first_name: "Robot",
      last_name: "Lizard",
    }
    body[:email] = email if email

    stub_request(
      :get,
      "https://graph.facebook.com/v5.0/me?appsecret_proof=#{appsecret_proof}&fields=name,first_name,last_name,email",
    ).with(headers: { "Authorization" => "OAuth #{access_token}" }).to_return(
      status: 200,
      body: JSON.dump(body),
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  before do
    SiteSetting.enable_facebook_logins = true
    SiteSetting.facebook_app_id = app_id
    SiteSetting.facebook_app_secret = app_secret

    stub_request(:post, "https://graph.facebook.com/v5.0/oauth/access_token").with(
      body:
        hash_including(
          "client_id" => app_id,
          "client_secret" => app_secret,
          "code" => temp_code,
          "grant_type" => "authorization_code",
          "redirect_uri" => "http://test.localhost/auth/facebook/callback",
        ),
    ).to_return(
      status: 200,
      body:
        Rack::Utils.build_query(access_token: access_token, scope: "email", token_type: "Bearer"),
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
      },
    )
  end

  it "signs in the user if the API response from facebook includes an email (implies it's verified) and the email matches an existing user's" do
    post "/auth/facebook"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://www.facebook.com/v5.0/dialog/oauth")

    setup_facebook_email_stub(email: user1.email)

    post "/auth/facebook/callback", params: { state: session["omniauth.state"], code: temp_code }

    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to eq(user1.id)
  end

  it "doesn't sign in anyone if the API response from facebook doesn't include an email (implying the user's email on facebook isn't verified)" do
    post "/auth/facebook"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://www.facebook.com/v5.0/dialog/oauth")

    setup_facebook_email_stub(email: nil)

    post "/auth/facebook/callback", params: { state: session["omniauth.state"], code: temp_code }

    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to be_blank
  end
end
