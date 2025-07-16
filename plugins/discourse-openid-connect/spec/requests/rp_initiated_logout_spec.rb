# frozen_string_literal: true

require "rails_helper"

describe "OIDC RP-Initiated Logout" do
  let(:document_url) do
    SiteSetting.openid_connect_discovery_document =
      "https://id.example.com/.well-known/openid-configuration"
  end
  let(:document) do
    {
      issuer: "https://id.example.com/",
      authorization_endpoint: "https://id.example.com/authorize",
      token_endpoint: "https://id.example.com/token",
      userinfo_endpoint: "https://id.example.com/userinfo",
      end_session_endpoint: "https://id.example.com/endsession",
    }
  end
  fab!(:user)

  before do
    SiteSetting.openid_connect_enabled = true
    SiteSetting.openid_connect_rp_initiated_logout = true
    stub_request(:get, document_url).to_return(body: lambda { |r| document.to_json })
  end

  after { Discourse.cache.delete("openid-connect-discovery-#{document_url}") }

  it "does nothing for a user with no oidc record" do
    sign_in(user)
    delete "/session/#{user.username}", xhr: true
    expect(response.status).to eq(200)
    expect(response.parsed_body["redirect_url"]).to eq("/")
  end

  it "does nothing for a user with no token in their oidc record" do
    sign_in(user)
    UserAssociatedAccount.create!(provider_name: "oidc", user: user, provider_uid: "myuid")
    delete "/session/#{user.username}", xhr: true
    expect(response.status).to eq(200)
    expect(response.parsed_body["redirect_url"]).to eq("/")
  end

  context "with user and token" do
    before do
      sign_in(user)
      UserAssociatedAccount.create!(
        provider_name: "oidc",
        user: user,
        provider_uid: "myuid",
        extra: {
          id_token: "myoidctoken",
        },
      )
    end

    it "redirects the user to the logout endpoint" do
      delete "/session/#{user.username}", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to eq(
        "https://id.example.com/endsession?id_token_hint=myoidctoken",
      )
    end

    it "correctly handles logout urls with existing query params" do
      document[:end_session_endpoint] += "?param=true"

      delete "/session/#{user.username}", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to eq(
        "https://id.example.com/endsession?param=true&id_token_hint=myoidctoken",
      )
    end

    it "includes the redirect URI if set" do
      SiteSetting.openid_connect_rp_initiated_logout_redirect = "https://example.com"
      delete "/session/#{user.username}", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to eq(
        "https://id.example.com/endsession?id_token_hint=myoidctoken&post_logout_redirect_uri=https%3A%2F%2Fexample.com",
      )
    end

    it "does not redirect if plugin disabled" do
      SiteSetting.openid_connect_enabled = false
      delete "/session/#{user.username}", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to eq("/")
    end

    it "does not redirect if rp initiated logout disabled" do
      SiteSetting.openid_connect_rp_initiated_logout = false
      delete "/session/#{user.username}", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to eq("/")
    end

    it "does not redirect if the discovery document is missing the endpoint" do
      stub_request(:get, document_url).to_return(body: "{}")
      SiteSetting.openid_connect_rp_initiated_logout = false
      delete "/session/#{user.username}", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to eq("/")
    end

    it "does not redirect if the discovery document has a network error" do
      stub_request(:get, document_url).to_timeout
      SiteSetting.openid_connect_rp_initiated_logout = false
      delete "/session/#{user.username}", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to eq("/")
    end
  end
end
