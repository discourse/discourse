# frozen_string_literal: true

require_relative "../../lib/omniauth_open_id_connect"

describe OmniAuth::Strategies::OpenIDConnect do
  subject(:strategy) do
    OmniAuth::Strategies::OpenIDConnect.new(
      app,
      "appid",
      "secret",
      discovery_document: discovery_document,
    )
  end

  let(:app) do
    @app_called = false
    lambda do |*args|
      @app_called = true
      [200, {}, ["Hello."]]
    end
  end

  let(:discovery_document) do
    {
      "issuer" => "https://id.example.com/",
      "authorization_endpoint" => "https://id.example.com/authorize",
      "token_endpoint" => "https://id.example.com/token",
      "userinfo_endpoint" => "https://id.example.com/userinfo",
    }
  end

  before { OmniAuth.config.test_mode = true }

  after { OmniAuth.config.test_mode = false }

  context "when discovery document is missing" do
    let(:discovery_document) { nil }

    it "throws an error" do
      expect { strategy.discover! }.to raise_error(::OmniAuth::OpenIDConnect::DiscoveryError)
    end
  end

  it "throws error for invalid discovery document" do
    discovery_document.delete("authorization_endpoint")
    expect { strategy.discover! }.to raise_error(::OmniAuth::OpenIDConnect::DiscoveryError)
  end

  it "disables userinfo if not included in discovery document" do
    discovery_document.delete("userinfo_endpoint")
    strategy.discover!
    expect(strategy.options.use_userinfo).to eq(false)
  end

  it "uses basic authentication when no endpoint auth methods are provided" do
    strategy.discover!
    expect(strategy.options.client_options.auth_scheme).to eq(:basic_auth)
  end

  it "uses basic authentication when both client_secret_basic and client_secret_post are provided" do
    discovery_document.merge!(
      { "token_endpoint_auth_methods_supported" => %w[client_secret_basic client_secret_post] },
    )
    strategy.discover!
    expect(strategy.options.client_options.auth_scheme).to eq(:basic_auth)
  end

  it "uses request_body authentication when client_secret_post is provided only" do
    discovery_document.merge!({ "token_endpoint_auth_methods_supported" => ["client_secret_post"] })
    strategy.discover!
    expect(strategy.options.client_options.auth_scheme).to eq(:request_body)
  end

  context "with valid discovery document loaded" do
    before do
      strategy.stubs(:request).returns(mock("object"))
      strategy
        .request
        .stubs(:params)
        .returns("p" => "someallowedvalue", "somethingelse" => "notallowed")
      strategy.options.claims = '{"userinfo":{"email":null,"email_verified":null}'
      strategy.discover!
    end

    it "loads parameters correctly" do
      expect(strategy.options.client_options.site).to eq("https://id.example.com/")
      expect(strategy.options.client_options.authorize_url).to eq(
        "https://id.example.com/authorize",
      )
      expect(strategy.options.client_options.token_url).to eq("https://id.example.com/token")
      expect(strategy.options.client_options.userinfo_endpoint).to eq(
        "https://id.example.com/userinfo",
      )
    end

    describe "authorize parameters" do
      it "passes through allowed parameters" do
        expect(strategy.authorize_params[:p]).to eq("someallowedvalue")
        expect(strategy.authorize_params[:somethingelse]).to eq(nil)

        expect(strategy.session["omniauth.param.p"]).to eq("someallowedvalue")
      end

      it "sets a nonce" do
        expect((nonce = strategy.authorize_params[:nonce]).size).to eq(64)
        expect(strategy.session["omniauth.nonce"]).to eq(nonce)
      end

      it "passes claims through to authorize endpoint if present" do
        expect(strategy.authorize_params[:claims]).to eq(
          '{"userinfo":{"email":null,"email_verified":null}',
        )
      end

      it "does not pass claims if empty string" do
        strategy.options.claims = ""
        expect(strategy.authorize_params[:claims]).to eq(nil)
      end
    end

    describe "token parameters" do
      it "passes through parameters from authorize phase" do
        expect(strategy.authorize_params[:p]).to eq("someallowedvalue")
        strategy.stubs(:request).returns(mock)
        strategy.request.stubs(:params).returns({})
        expect(strategy.token_params[:p]).to eq("someallowedvalue")
      end
    end

    describe "callback_phase" do
      before do
        auth_params = strategy.authorize_params

        strategy.stubs(:full_host).returns("https://example.com")

        strategy.stubs(:request).returns(mock)
        strategy
          .request
          .stubs(:params)
          .returns("state" => auth_params[:state], "code" => "supersecretcode")

        payload = {
          iss: "https://id.example.com/",
          sub: "someuserid",
          aud: "appid",
          iat: Time.now.to_i - 30,
          exp: Time.now.to_i + 120,
          nonce: auth_params[:nonce],
          name: "My Auth Token Name",
          email: "tokenemail@example.com",
        }
        @token = ::JWT.encode payload, nil, "none"
      end

      it "handles error redirects correctly" do
        strategy.stubs(:request).returns(mock)
        strategy
          .request
          .stubs(:params)
          .returns("error" => true, "error_description" => "User forgot password")
        strategy.options.error_handler =
          lambda do |error, message|
            "https://example.com/error_redirect" if message.include?("forgot password")
          end
        expect(strategy.callback_phase[0]).to eq(302)
        expect(strategy.callback_phase[1]["Location"]).to eq("https://example.com/error_redirect")
        expect(@app_called).to eq(false)
      end

      context "with userinfo disabled" do
        before do
          stub_request(:post, "https://id.example.com/token").with(
            body: hash_including("code" => "supersecretcode", "p" => "someallowedvalue"),
          ).to_return(
            status: 200,
            body: { id_token: @token }.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
          )

          strategy.options.use_userinfo = false
        end

        it "fetches auth token correctly, and uses it for user info" do
          expect(strategy.callback_phase[0]).to eq(200)
          expect(strategy.uid).to eq("someuserid")
          expect(strategy.info[:name]).to eq("My Auth Token Name")
          expect(strategy.info[:email]).to eq("tokenemail@example.com")
          expect(strategy.extra[:id_token]).to eq(@token)
          expect(@app_called).to eq(true)
        end

        it "checks the nonce" do
          strategy.session["omniauth.nonce"] = "overriddenNonce"
          expect(strategy.callback_phase[0]).to eq(302)
          expect(@app_called).to eq(false)
        end

        it "checks the issuer" do
          strategy.options.client_id = "overriddenclientid"
          expect(strategy.callback_phase[0]).to eq(302)
          expect(@app_called).to eq(false)
        end
      end

      context "with userinfo enabled" do
        let(:userinfo_response) do
          { sub: "someuserid", name: "My Userinfo Name", email: "userinfoemail@example.com" }
        end

        before do
          stub_request(:post, "https://id.example.com/token").with(
            body: hash_including("code" => "supersecretcode", "p" => "someallowedvalue"),
          ).to_return(
            status: 200,
            body: { access_token: "AnAccessToken", expires_in: 3600, id_token: @token }.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
          )

          stub_request(:get, "https://id.example.com/userinfo")
            .with(headers: { "Authorization" => "Bearer AnAccessToken" })
            .to_return do |request|
              {
                status: 200,
                body: userinfo_response.to_json,
                headers: {
                  "Content-Type" => "application/json",
                },
              }
            end
        end

        it "fetches credentials and auth token correctly" do
          expect(strategy.callback_phase[0]).to eq(200)
          expect(strategy.uid).to eq("someuserid")
          expect(strategy.info[:name]).to eq("My Userinfo Name")
          expect(strategy.info[:email]).to eq("userinfoemail@example.com")
          expect(@app_called).to eq(true)
        end

        it "handles mismatching `sub` correctly" do
          userinfo_response["sub"] = "someothersub"
          callback_response = strategy.callback_phase
          expect(callback_response[0]).to eq(302)
          expect(callback_response[1]["Location"]).to eq(
            "/auth/failure?message=openid_connect_sub_mismatch&strategy=openidconnect",
          )
          expect(@app_called).to eq(false)
        end

        it "exposes id_token_info alongside the userinfo raw_info" do
          expect(strategy.callback_phase[0]).to eq(200)
          expect(strategy.extra[:raw_info]["email"]).to eq("userinfoemail@example.com")
          expect(strategy.extra[:id_token_info]["email"]).to eq("tokenemail@example.com")
        end
      end
    end
  end

  context "with mTLS client certificate configured" do
    before do
      key = OpenSSL::PKey::RSA.new(2048)
      cert = OpenSSL::X509::Certificate.new
      cert.subject = OpenSSL::X509::Name.parse("/CN=test")
      cert.issuer = cert.subject
      cert.not_before = Time.now
      cert.not_after = Time.now + 365 * 86_400
      cert.public_key = key.public_key
      cert.sign(key, OpenSSL::Digest.new("SHA256"))

      strategy.options.client_options[:auth_scheme] = :tls_client_auth
      strategy.options.client_options[:connection_opts] ||= {}
      strategy.options.client_options[:connection_opts][:ssl] = {
        client_cert: cert,
        client_key: key,
      }
    end

    before do
      strategy.stubs(:full_host).returns("https://example.com")
      strategy.stubs(:request).returns(mock)
      strategy.request.stubs(:params).returns({})

      auth_params = strategy.authorize_params
      strategy
        .request
        .stubs(:params)
        .returns("state" => auth_params[:state], "code" => "supersecretcode")

      payload = {
        iss: "https://id.example.com/",
        sub: "someuserid",
        aud: "appid",
        iat: Time.now.to_i - 30,
        exp: Time.now.to_i + 120,
        nonce: auth_params[:nonce],
        name: "My Auth Token Name",
        email: "tokenemail@example.com",
      }
      @token = ::JWT.encode payload, nil, "none"

      stub_request(:post, "https://id.example.com/token")
        .with { |request| @request_body = request.body }
        .to_return(
          status: 200,
          body: { access_token: "MTLSAccessToken", expires_in: 3600, id_token: @token }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      stub_request(:get, "https://id.example.com/userinfo").with(
        headers: {
          "Authorization" => "Bearer MTLSAccessToken",
        },
      ).to_return(
        status: 200,
        body: {
          sub: "someuserid",
          name: "My Userinfo Name",
          email: "userinfoemail@example.com",
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
    end

    it "uses mTLS authentication instead of client_secret" do
      expect(strategy.options.client_options.auth_scheme).to eq(:tls_client_auth)

      ssl = strategy.options.client_options.connection_opts[:ssl]
      expect(ssl[:client_cert]).to be_a(OpenSSL::X509::Certificate)
      expect(ssl[:client_key]).to be_a(OpenSSL::PKey::RSA)

      callback_response = strategy.callback_phase
      expect(callback_response[0]).to eq(200)

      expect(@request_body).to include("client_id")
      expect(@request_body).not_to include("client_secret")
    end
  end
end
