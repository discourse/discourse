# frozen_string_literal: true

require_relative "../../lib/omniauth_open_id_connect"

describe OpenIDConnectAuthenticator do
  let(:authenticator) { described_class.new }
  fab!(:user)
  let(:hash) do
    OmniAuth::AuthHash.new(
      provider: "oidc",
      uid: "123456789",
      info: {
        name: "John Doe",
        email: user.email,
      },
      extra: {
        raw_info: {
          email: user.email,
          name: "John Doe",
        },
      },
    )
  end

  context "when email_verified is not supplied" do
    # Some IDPs do not supply this information
    # In this case we trust that they have verified the address
    it "matches the user" do
      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(user)
    end
  end

  context "when email_verified is true" do
    it "matches the user" do
      hash[:extra][:raw_info][:email_verified] = true
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(user)
    end

    it "matches the user as a true string" do
      hash[:extra][:raw_info][:email_verified] = "true"
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(user)
    end

    it "matches the user as a titlecase true string" do
      hash[:extra][:raw_info][:email_verified] = "True"
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(user)
    end
  end

  context "when email_verified is false" do
    it "does not match the user" do
      hash[:extra][:raw_info][:email_verified] = false
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(nil)
    end

    it "does not match the user as a false string" do
      hash[:extra][:raw_info][:email_verified] = "false"
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(nil)
    end
  end

  context "when match_by_email is false" do
    it "does not match the user" do
      SiteSetting.openid_connect_match_by_email = false
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(nil)
    end
  end

  describe "group syncing" do
    context "when openid_connect_groups_claim is blank" do
      it "does not provide groups" do
        expect(authenticator.provides_groups?).to eq(false)
      end

      it "does not set associated_groups" do
        hash[:extra][:raw_info][:groups] = %w[group1 group2]
        result = authenticator.after_authenticate(hash)
        expect(result.associated_groups).to be_nil
      end
    end

    context "when openid_connect_groups_claim is set" do
      before { SiteSetting.openid_connect_groups_claim = "groups" }

      it "provides groups" do
        expect(authenticator.provides_groups?).to eq(true)
      end

      it "extracts groups from the claim" do
        hash[:extra][:raw_info][:groups] = %w[group1 group2]
        result = authenticator.after_authenticate(hash)
        expect(result.associated_groups).to eq(
          [{ id: "group1", name: "group1" }, { id: "group2", name: "group2" }],
        )
      end

      it "handles an empty groups array" do
        hash[:extra][:raw_info][:groups] = []
        result = authenticator.after_authenticate(hash)
        expect(result.associated_groups).to eq([])
      end

      it "does not set associated_groups when the claim is missing" do
        result = authenticator.after_authenticate(hash)
        expect(result.associated_groups).to be_nil
      end

      it "logs an error when the claim is not an array" do
        hash[:extra][:raw_info][:groups] = "not_an_array"
        Rails.logger.expects(:error).with(includes("not an array"))
        result = authenticator.after_authenticate(hash)
        expect(result.associated_groups).to be_nil
      end
    end

    context "with a custom claim name" do
      before { SiteSetting.openid_connect_groups_claim = "cognito:groups" }

      it "reads from the correct claim" do
        hash[:extra][:raw_info]["cognito:groups"] = %w[admins editors]
        result = authenticator.after_authenticate(hash)
        expect(result.associated_groups).to eq(
          [{ id: "admins", name: "admins" }, { id: "editors", name: "editors" }],
        )
      end
    end
  end

  describe "discovery document fetching" do
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
      }.to_json
    end
    after { Discourse.cache.delete("openid-connect-discovery-#{document_url}") }

    it "loads the document correctly" do
      stub_request(:get, document_url).to_return(body: document)
      expect(authenticator.discovery_document.keys).to contain_exactly(
        "issuer",
        "authorization_endpoint",
        "token_endpoint",
        "userinfo_endpoint",
      )
    end

    it "handles a non-200 response" do
      stub_request(:get, document_url).to_return(status: 404)
      expect(authenticator.discovery_document).to eq(nil)
    end

    it "handles a network error" do
      stub_request(:get, document_url).to_timeout
      expect(authenticator.discovery_document).to eq(nil)
    end

    it "handles invalid json" do
      stub_request(:get, document_url).to_return(body: "this is not the json you're looking for")
      expect(authenticator.discovery_document).to eq(nil)
    end

    it "caches a success response" do
      stub = stub_request(:get, document_url).to_return(body: document)
      expect(authenticator.discovery_document).not_to eq(nil)
      expect(authenticator.discovery_document).not_to eq(nil)
      expect(stub).to have_been_requested.once
    end

    it "caches a failed response" do
      stub = stub_request(:get, document_url).to_return(status: 404)
      expect(authenticator.discovery_document).to eq(nil)
      expect(authenticator.discovery_document).to eq(nil)
      expect(stub).to have_been_requested.once
    end
  end
end
