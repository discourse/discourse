# frozen_string_literal: true

require_relative "../../lib/omniauth_apple"
require "rails_helper"

pem = ::OpenSSL::PKey::EC.generate("prime256v1").to_pem

describe "sign in with apple" do
  let(:jwk) { ::JWT::JWK.new(OpenSSL::PKey::RSA.generate(1024)) }

  before do
    Discourse.cache.delete("sign-in-with-apple-jwks")
    SiteSetting.sign_in_with_apple_enabled = true
    SiteSetting.apple_client_id = "myclientid"
    SiteSetting.apple_team_id = "myteamid"
    SiteSetting.apple_key_id = "mykeyid"
    SiteSetting.apple_pem = pem

    stub_request(:get, "https://appleid.apple.com/auth/keys").to_return(
      body: { keys: [jwk.export] }.to_json,
    )
  end

  let(:user_payload) do
    { email: "maybe-spoofed-email@example.com", name: { firstName: "Disco", lastName: "Bot" } }
  end

  it "starts the flow correctly" do
    post "/auth/apple"
    expect(response.status).to eq(302)
    expect(response.location).to start_with("https://appleid.apple.com/auth/authorize")
    expect(response.location).to include("client_id=myclientid")
  end

  describe "POST callback" do
    # Apple send the callback as a POST, which is incompatible
    # with samesite=lax cookies

    it "redirects to GET" do
      post "/auth/apple/callback", params: { code: "supersecretcode", state: "uniquestate" }
      expect(response.status).to eq(302)
      expect(response.location).to eq(
        "http://test.localhost/auth/apple/callback?code=supersecretcode&state=uniquestate",
      )
    end

    it "includes the user data if present" do
      post "/auth/apple/callback",
           params: {
             code: "supersecretcode",
             state: "uniquestate",
             user: user_payload.to_json,
           }
      expect(response.status).to eq(302)
      expect(response.location).to include("user=%7B")
    end

    it "does not set any cookies" do
      # This cross-site request has no cookies (because they're samesite=lax)
      # By default the session middleware will try and start a new session
      # which would break the existing session
      post "/auth/apple/callback"
      expect(response.status).to eq(302)
      expect(response.headers["Set-Cookie"]).to eq(nil)
    end
  end

  describe "GET callback" do
    before do
      post "/auth/apple"
      expect(response.status).to eq(302)

      # Mock the apple server
      stub_request(:post, "https://appleid.apple.com/auth/token").to_return do |request|
        # https://developer.apple.com/documentation/sign_in_with_apple/generate_and_validate_tokens
        # https://developer.apple.com/documentation/sign_in_with_apple/tokenresponse

        params = Rack::Utils.parse_nested_query(request.body)

        expect(params["client_id"]).to eq("myclientid")
        expect(params["code"]).to eq("supersecretcode")

        decoded, header = JWT.decode(params["client_secret"], nil, false)
        expect(decoded["iss"]).to eq("myteamid")
        expect(decoded["sub"]).to eq("myclientid")
        expect(header["kid"]).to eq("mykeyid")

        {
          status: 200,
          body: {
            access_token: "wedontusethis",
            expires_in: 10,
            id_token:
              ::JWT.encode(
                {
                  iss: "https://appleid.apple.com",
                  aud: "myclientid",
                  sub: "unique-user-id",
                  email: "verified-email@example.com",
                },
                jwk.keypair,
                "RS256",
                { kid: jwk.kid },
              ),
            refresh_token: "wedontusethis",
            token_type: "bearer",
          }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        }
      end
    end

    it "works" do
      # Like an OAuth2 callback, but with some apple-specific stuff per
      # https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_js/incorporating_sign_in_with_apple_into_other_platforms
      get "/auth/apple/callback",
          params: {
            code: "supersecretcode",
            state: session["omniauth.state"],
            id_token: JWT.encode({ email: "wedontusethis" }, nil, "none"),
            user: user_payload.to_json,
          }
      expect(response.status).to eq(302)
      expect(response.location).to eq("http://test.localhost/")

      result = Auth::Result.from_session_data(session[:authentication], user: nil)
      expect(result.email).to eq("verified-email@example.com")
      expect(result.name).to eq("Disco Bot")
      expect(result.extra_data[:uid]).to eq("unique-user-id")
    end
  end
end
