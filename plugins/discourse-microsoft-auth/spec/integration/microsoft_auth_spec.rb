# frozen_string_literal: true

describe "Microsoft OAuth2" do
  let(:access_token) { "microsoft_access_token_448" }
  let(:client_id) { "abcdef11223344" }
  let(:client_secret) { "adddcccdddd99922" }
  let(:temp_code) { "microsoft_temp_code_544254" }

  fab!(:user1) { Fabricate(:user) }

  def setup_ms_emails_stub(email:)
    stub_request(:get, "https://graph.microsoft.com/v1.0/me").with(
      headers: {
        "Authorization" => "Bearer #{access_token}",
      },
    ).to_return(
      status: 200,
      body:
        JSON.dump(
          businessPhones: ["+1 425 555 0109"],
          displayName: "Adele Vance",
          givenName: "Adele",
          jobTitle: "Retail Manager",
          mail: email,
          mobilePhone: "+1 425 555 0109",
          officeLocation: "18/2111",
          preferredLanguage: "en-US",
          surname: "Vance",
          userPrincipalName: email,
          id: "87d349ed-44d7-43e1-9a83-5f2406dee5bd",
        ),
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  before do
    SiteSetting.microsoft_auth_enabled = true
    SiteSetting.microsoft_auth_client_id = client_id
    SiteSetting.microsoft_auth_client_secret = client_secret

    stub_request(:post, "https://login.microsoftonline.com/common/oauth2/v2.0/token").with(
      body:
        hash_including(
          "client_id" => client_id,
          "client_secret" => client_secret,
          "code" => temp_code,
          "grant_type" => "authorization_code",
          "redirect_uri" => "http://test.localhost/auth/microsoft_office365/callback",
        ),
    ).to_return(
      status: 200,
      body:
        Rack::Utils.build_query(
          access_token: access_token,
          token_type: "Bearer",
          expires_in: 3599,
          scope: "openid email profile https://graph.microsoft.com/User.Read",
        ),
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
      },
    )
  end

  it "signs in the user whose email matches the email included in the API response from microsoft when `microsoft_auth_email_verified` site setting is true" do
    SiteSetting.microsoft_auth_email_verified = true

    post "/auth/microsoft_office365"

    expect(response.status).to eq(302)
    expect(response.location).to start_with(
      "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
    )

    setup_ms_emails_stub(email: user1.email)

    post "/auth/microsoft_office365/callback",
         params: {
           state: session["omniauth.state"],
           code: temp_code,
         }

    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to eq(user1.id)
  end

  it "does not sign in the user whose email matches the email included in the API response from microsoft when `microsoft_auth_email_verified` site setting is false" do
    SiteSetting.microsoft_auth_email_verified = false

    post "/auth/microsoft_office365"

    expect(response.status).to eq(302)
    expect(response.location).to start_with(
      "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
    )

    setup_ms_emails_stub(email: user1.email)

    post "/auth/microsoft_office365/callback",
         params: {
           state: session["omniauth.state"],
           code: temp_code,
         }

    expect(response.status).to eq(302)
    expect(response.location).to eq("http://test.localhost/")
    expect(session[:current_user_id]).to eq(nil)
  end

  context "when configured as single tenant" do
    it "uses the tenant id from the site setting" do
      SiteSetting.microsoft_auth_tenant_id = "my-tenant-id"

      post "/auth/microsoft_office365"

      expect(response.status).to eq(302)
      expect(response.location).to start_with(
        "https://login.microsoftonline.com/my-tenant-id/oauth2/v2.0/authorize",
      )
    end
  end
end
