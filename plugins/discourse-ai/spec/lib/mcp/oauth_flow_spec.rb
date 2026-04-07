# frozen_string_literal: true

RSpec.describe DiscourseAi::Mcp::OAuthFlow do
  fab!(:user)
  fab!(:oauth_client_secret, :ai_secret)
  fab!(:ai_mcp_server) { Fabricate(:ai_mcp_server, auth_type: "oauth") }

  before do
    enable_current_plugin
    AiMcpServer.stubs(:validate_hostname_public!).returns(true)
  end

  describe ".start!" do
    it "rejects insecure Discourse site URLs before starting OAuth" do
      Discourse.stubs(:base_url).returns("http://mcp.home.arpa")

      expect { described_class.start!(server: ai_mcp_server, user: user) }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        I18n.t("discourse_ai.mcp_servers.errors.oauth_https_required"),
      )
    end

    it "performs dynamic client registration when a registration_endpoint is discovered" do
      Discourse.stubs(:base_url).returns("https://discourse.example.com")
      discovery =
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
          registration_endpoint: "https://auth.example.com/register",
        )
      DiscourseAi::Mcp::OAuthDiscovery.stubs(:discover!).returns(discovery)

      stub_request(:post, "https://auth.example.com/register").to_return(
        status: 201,
        body: { client_id: "dynamic-id-456" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      url = described_class.start!(server: ai_mcp_server, user: user)

      expect(ai_mcp_server.reload.oauth_client_id).to eq("dynamic-id-456")
      expect(url).to include("client_id=dynamic-id-456")
    end

    it "skips dynamic registration when client_id is already present" do
      Discourse.stubs(:base_url).returns("https://discourse.example.com")
      ai_mcp_server.update_columns(oauth_client_id: "existing-client-id")

      discovery =
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
          registration_endpoint: "https://auth.example.com/register",
        )
      DiscourseAi::Mcp::OAuthDiscovery.stubs(:discover!).returns(discovery)

      url = described_class.start!(server: ai_mcp_server, user: user)

      expect(url).to include("client_id=existing-client-id")
      expect(a_request(:post, "https://auth.example.com/register")).not_to have_been_made
    end

    it "skips dynamic registration for manual registration mode" do
      Discourse.stubs(:base_url).returns("https://discourse.example.com")
      ai_mcp_server.update!(oauth_client_registration: "manual", oauth_client_id: "manual-id")

      discovery =
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
          registration_endpoint: "https://auth.example.com/register",
        )
      DiscourseAi::Mcp::OAuthDiscovery.stubs(:discover!).returns(discovery)

      url = described_class.start!(server: ai_mcp_server, user: user)

      expect(url).to include("client_id=manual-id")
      expect(a_request(:post, "https://auth.example.com/register")).not_to have_been_made
    end

    it "requires manual registration when the auth server does not advertise dynamic registration" do
      Discourse.stubs(:base_url).returns("https://discourse.example.com")

      discovery =
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://accounts.google.com",
          authorization_endpoint: "https://accounts.google.com/o/oauth2/v2/auth",
          token_endpoint: "https://oauth2.googleapis.com/token",
          revocation_endpoint: "https://oauth2.googleapis.com/revoke",
          registration_endpoint: nil,
          token_endpoint_auth_methods_supported: %w[client_secret_post client_secret_basic],
        )
      DiscourseAi::Mcp::OAuthDiscovery.stubs(:discover!).returns(discovery)

      expect { described_class.start!(server: ai_mcp_server, user: user) }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        I18n.t(
          "discourse_ai.mcp_servers.errors.oauth_manual_client_registration_required",
          issuer: "https://accounts.google.com",
        ),
      )
    end

    it "requires a client secret when the token endpoint does not support public clients" do
      Discourse.stubs(:base_url).returns("https://discourse.example.com")
      ai_mcp_server.update!(oauth_client_registration: "manual", oauth_client_id: "manual-id")

      discovery =
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://accounts.google.com",
          authorization_endpoint: "https://accounts.google.com/o/oauth2/v2/auth",
          token_endpoint: "https://oauth2.googleapis.com/token",
          revocation_endpoint: "https://oauth2.googleapis.com/revoke",
          registration_endpoint: nil,
          token_endpoint_auth_methods_supported: %w[client_secret_post client_secret_basic],
        )
      DiscourseAi::Mcp::OAuthDiscovery.stubs(:discover!).returns(discovery)

      expect { described_class.start!(server: ai_mcp_server, user: user) }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        I18n.t(
          "discourse_ai.mcp_servers.errors.oauth_client_secret_required",
          issuer: "https://accounts.google.com",
          methods: "client_secret_post, client_secret_basic",
        ),
      )
    end

    it "allows client_secret_post-only token endpoints when a client secret is configured" do
      Discourse.stubs(:base_url).returns("https://discourse.example.com")
      ai_mcp_server.update!(
        oauth_client_registration: "manual",
        oauth_client_id: "manual-id",
        oauth_client_secret_ai_secret_id: oauth_client_secret.id,
      )

      discovery =
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
          registration_endpoint: nil,
          token_endpoint_auth_methods_supported: %w[client_secret_post],
        )
      DiscourseAi::Mcp::OAuthDiscovery.stubs(:discover!).returns(discovery)

      url = described_class.start!(server: ai_mcp_server, user: user)

      expect(url).to include("client_id=manual-id")
    end

    it "rejects token endpoints that only advertise unsupported client auth methods" do
      Discourse.stubs(:base_url).returns("https://discourse.example.com")
      ai_mcp_server.update!(
        oauth_client_registration: "manual",
        oauth_client_id: "manual-id",
        oauth_client_secret_ai_secret_id: oauth_client_secret.id,
      )

      discovery =
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
          registration_endpoint: nil,
          token_endpoint_auth_methods_supported: %w[private_key_jwt],
        )
      DiscourseAi::Mcp::OAuthDiscovery.stubs(:discover!).returns(discovery)

      expect { described_class.start!(server: ai_mcp_server, user: user) }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        I18n.t(
          "discourse_ai.mcp_servers.errors.oauth_token_endpoint_auth_method_unsupported",
          issuer: "https://auth.example.com",
          methods: "private_key_jwt",
        ),
      )
    end

    it "merges advanced authorization params into the authorization request" do
      Discourse.stubs(:base_url).returns("https://discourse.example.com")
      ai_mcp_server.update!(
        oauth_client_registration: "manual",
        oauth_client_id: "manual-id",
        oauth_authorization_params: {
          "access_type" => "offline",
          "resource" => nil,
        },
      )

      discovery =
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
          registration_endpoint: "https://auth.example.com/register",
        )
      DiscourseAi::Mcp::OAuthDiscovery.stubs(:discover!).returns(discovery)

      uri = URI(described_class.start!(server: ai_mcp_server, user: user))
      query = Rack::Utils.parse_nested_query(uri.query)

      expect(query["client_id"]).to eq("manual-id")
      expect(query["access_type"]).to eq("offline")
      expect(query).not_to have_key("resource")
    end
  end

  describe ".complete!" do
    it "wraps token exchange errors in OAuthError with the server attached" do
      ai_mcp_server.update_columns(
        oauth_authorization_endpoint: "https://auth.example.com/authorize",
        oauth_token_endpoint: "https://auth.example.com/token",
        oauth_issuer: "https://auth.example.com",
      )

      state = SecureRandom.hex(32)
      Rails.cache.write(
        "discourse-ai:mcp-oauth-state:#{state}",
        {
          "ai_mcp_server_id" => ai_mcp_server.id,
          "user_id" => user.id,
          "code_verifier" => "test-verifier",
        },
        expires_in: 10.minutes,
      )

      stub_request(:post, "https://auth.example.com/token").to_return(
        status: 400,
        body: { error: "invalid_client", error_description: "Client not found" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      expect {
        described_class.complete!(params: { state: state, code: "auth-code" }, current_user: user)
      }.to raise_error(described_class::OAuthError, "Client not found") { |error|
        expect(error.server).to eq(ai_mcp_server)
        expect(error.cause).to be_a(DiscourseAi::Mcp::Client::Error)
      }

      expect(ai_mcp_server.reload.oauth_status).to eq("error")
      expect(ai_mcp_server.oauth_last_error).to eq("Client not found")
    end

    it "merges advanced token params and can require a refresh token" do
      ai_mcp_server.update!(
        oauth_client_registration: "manual",
        oauth_client_id: "client-id",
        oauth_require_refresh_token: true,
        oauth_token_params: {
          "audience" => "https://bigquery.googleapis.com/",
          "resource" => nil,
        },
      )
      ai_mcp_server.update_columns(
        oauth_authorization_endpoint: "https://auth.example.com/authorize",
        oauth_token_endpoint: "https://auth.example.com/token",
        oauth_issuer: "https://auth.example.com",
      )

      state = SecureRandom.hex(32)
      Rails.cache.write(
        "discourse-ai:mcp-oauth-state:#{state}",
        {
          "ai_mcp_server_id" => ai_mcp_server.id,
          "user_id" => user.id,
          "code_verifier" => "test-verifier",
        },
        expires_in: 10.minutes,
      )

      stub_request(:post, "https://auth.example.com/token")
        .with do |request|
          decoded_body = Rack::Utils.parse_nested_query(request.body)
          decoded_body["audience"] == "https://bigquery.googleapis.com/" &&
            !decoded_body.key?("resource")
        end
        .to_return(
          status: 200,
          body: { access_token: "fresh-access-token", token_type: "Bearer" }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      expect {
        described_class.complete!(params: { state: state, code: "auth-code" }, current_user: user)
      }.to raise_error(
        described_class::OAuthError,
        I18n.t("discourse_ai.mcp_servers.errors.oauth_refresh_token_required"),
      )

      expect(ai_mcp_server.reload.oauth_status).to eq("error")
      expect(ai_mcp_server.oauth_last_error).to eq(
        I18n.t("discourse_ai.mcp_servers.errors.oauth_refresh_token_required"),
      )
    end
  end

  describe ".refresh!" do
    it "uses HTTP basic auth without sending client_secret in the request body" do
      ai_mcp_server.update!(
        oauth_client_registration: "manual",
        oauth_client_id: "client-id",
        oauth_client_secret_ai_secret_id: oauth_client_secret.id,
        oauth_token_params: {
          "audience" => "https://bigquery.googleapis.com/",
          "resource" => nil,
        },
      )
      ai_mcp_server.oauth_token_store.write!(
        access_token: "expired-access-token",
        refresh_token: "refresh-token",
      )
      ai_mcp_server.stubs(:oauth_discovery_result).returns(
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
        ),
      )

      stub_request(:post, "https://auth.example.com/token")
        .with do |request|
          decoded_body = Rack::Utils.parse_nested_query(request.body)
          request.headers["Authorization"] ==
            "Basic #{Base64.strict_encode64("client-id:#{oauth_client_secret.secret}")}" &&
            decoded_body["refresh_token"] == "refresh-token" &&
            decoded_body["audience"] == "https://bigquery.googleapis.com/" &&
            !decoded_body.key?("client_secret") && !decoded_body.key?("resource")
        end
        .to_return(
          status: 200,
          body: {
            access_token: "fresh-access-token",
            refresh_token: "fresh-refresh-token",
            token_type: "Bearer",
          }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      described_class.refresh!(ai_mcp_server)

      expect(ai_mcp_server.reload.oauth_token.access_token).to eq("fresh-access-token")
      expect(ai_mcp_server.oauth_token.refresh_token).to eq("fresh-refresh-token")
    end

    it "uses client_secret_post when the token endpoint only supports body authentication" do
      ai_mcp_server.update!(
        oauth_client_registration: "manual",
        oauth_client_id: "client-id",
        oauth_client_secret_ai_secret_id: oauth_client_secret.id,
      )
      ai_mcp_server.oauth_token_store.write!(
        access_token: "expired-access-token",
        refresh_token: "refresh-token",
      )
      ai_mcp_server.stubs(:oauth_discovery_result).returns(
        DiscourseAi::Mcp::OAuthDiscovery::Result.new(
          resource: ai_mcp_server.url,
          resource_metadata_url: "#{ai_mcp_server.url}/.well-known/oauth-protected-resource",
          issuer: "https://auth.example.com",
          authorization_endpoint: "https://auth.example.com/authorize",
          token_endpoint: "https://auth.example.com/token",
          revocation_endpoint: nil,
          token_endpoint_auth_methods_supported: %w[client_secret_post],
        ),
      )

      stub_request(:post, "https://auth.example.com/token")
        .with do |request|
          decoded_body = Rack::Utils.parse_nested_query(request.body)
          request.headers["Authorization"].blank? && decoded_body["client_id"] == "client-id" &&
            decoded_body["client_secret"] == oauth_client_secret.secret &&
            decoded_body["refresh_token"] == "refresh-token"
        end
        .to_return(
          status: 200,
          body: {
            access_token: "fresh-access-token",
            refresh_token: "fresh-refresh-token",
            token_type: "Bearer",
          }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      described_class.refresh!(ai_mcp_server)

      expect(ai_mcp_server.reload.oauth_token.access_token).to eq("fresh-access-token")
      expect(ai_mcp_server.oauth_token.refresh_token).to eq("fresh-refresh-token")
    end
  end
end
