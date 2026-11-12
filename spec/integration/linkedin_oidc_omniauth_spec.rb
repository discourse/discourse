# frozen_string_literal: true

describe "LinkedIn OIDC" do
  let(:access_token) { "linkedin_access_token_448" }
  let(:client_id) { "abcdef11223344" }
  let(:client_secret) { "adddcccdddd99922" }
  let(:temp_code) { "linkedin_temp_code_544254" }

  fab!(:user)

  before do
    SiteSetting.linkedin_oidc_client_id = client_id
    SiteSetting.linkedin_oidc_client_secret = client_secret
    SiteSetting.enable_linkedin_oidc_logins = true

    stub_request(:get, "https://api.linkedin.com/v2/userinfo").with(
      headers: {
        "Authorization" => "Bearer #{access_token}",
      },
    ).to_return(
      status: 200,
      body:
        JSON.dump(
          sub: "782bbtaQ",
          name: "John Doe",
          given_name: "John",
          family_name: "Doe",
          picture: "https://media.licdn.com/dms/image/example.jpg",
          email: user.email,
          email_verified: true,
        ),
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  it "sends client credentials in the token request body rather than a basic auth header" do
    token_request =
      stub_request(:post, "https://www.linkedin.com/oauth/v2/accessToken").with(
        body:
          hash_including(
            "client_id" => client_id,
            "client_secret" => client_secret,
            "code" => temp_code,
            "grant_type" => "authorization_code",
          ),
      ).to_return(
        status: 200,
        body:
          JSON.dump(
            access_token: access_token,
            token_type: "Bearer",
            expires_in: 5_183_999,
            scope: "openid,profile,email",
          ),
        headers: {
          "Content-Type" => "application/json",
        },
      )

    post "/auth/linkedin_oidc"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://www.linkedin.com/oauth/v2/authorization?")

    post "/auth/linkedin_oidc/callback",
         params: {
           state: session["omniauth.state"],
           code: temp_code,
         }
    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to eq(user.id)

    expect(token_request).to have_been_requested.once
    expect(
      a_request(:post, "https://www.linkedin.com/oauth/v2/accessToken").with do |req|
        req.headers["Authorization"].present?
      end,
    ).not_to have_been_made
  end
end
