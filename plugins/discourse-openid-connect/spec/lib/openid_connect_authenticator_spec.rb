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

      it "treats a missing claim as an empty groups list" do
        result = authenticator.after_authenticate(hash)
        expect(result.associated_groups).to eq([])
      end

      it "logs an error and clears groups when the claim is not an array" do
        hash[:extra][:raw_info][:groups] = "not_an_array"
        Rails.logger.expects(:error).with(includes("not an array"))
        result = authenticator.after_authenticate(hash)
        expect(result.associated_groups).to eq([])
      end

      it "falls back to the id_token when the claim is missing from raw_info" do
        hash[:extra][:id_token_info] = { "groups" => %w[group1 group2] }
        result = authenticator.after_authenticate(hash)
        expect(result.associated_groups).to eq(
          [{ id: "group1", name: "group1" }, { id: "group2", name: "group2" }],
        )
      end

      it "prefers raw_info over the id_token when both contain the claim" do
        hash[:extra][:raw_info][:groups] = %w[from_userinfo]
        hash[:extra][:id_token_info] = { "groups" => %w[from_id_token] }
        result = authenticator.after_authenticate(hash)
        expect(result.associated_groups).to eq([{ id: "from_userinfo", name: "from_userinfo" }])
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

  describe "user field syncing" do
    fab!(:user_field)

    it "leaves user_field_values empty when no mappings are configured" do
      result = authenticator.after_authenticate(hash)
      expect(result.user_field_values).to eq({})
    end

    context "with a mapping configured" do
      before do
        SiteSetting.openid_connect_user_field_mappings = [
          { "claim" => "department", "user_field_id" => user_field.id },
        ].to_json
      end

      it "pulls the value from raw_info" do
        hash[:extra][:raw_info][:department] = "Engineering"
        result = authenticator.after_authenticate(hash)
        expect(result.user_field_values).to eq(user_field.id.to_s => "Engineering")
      end

      it "falls back to id_token_info when the claim is missing from raw_info" do
        hash[:extra][:id_token_info] = { "department" => "Engineering" }
        result = authenticator.after_authenticate(hash)
        expect(result.user_field_values).to eq(user_field.id.to_s => "Engineering")
      end

      it "joins array values with commas" do
        hash[:extra][:raw_info][:department] = %w[Eng Ops]
        result = authenticator.after_authenticate(hash)
        expect(result.user_field_values).to eq(user_field.id.to_s => "Eng,Ops")
      end

      it "skips mappings whose claim is missing entirely" do
        result = authenticator.after_authenticate(hash)
        expect(result.user_field_values).to eq({})
      end

      it "clears the field when raw_info has the claim set to an empty string" do
        hash[:extra][:raw_info][:department] = ""
        hash[:extra][:id_token_info] = { "department" => "Engineering" }
        result = authenticator.after_authenticate(hash)
        expect(result.user_field_values).to eq(user_field.id.to_s => "")
      end

      it "clears the field when raw_info has the claim set to null" do
        hash[:extra][:raw_info][:department] = nil
        hash[:extra][:id_token_info] = { "department" => "Engineering" }
        result = authenticator.after_authenticate(hash)
        expect(result.user_field_values).to eq(user_field.id.to_s => "")
      end
    end
  end

  describe "mTLS support" do
    let!(:mtls_key) { OpenSSL::PKey::RSA.new(2048) }
    let!(:mtls_cert) do
      cert = OpenSSL::X509::Certificate.new
      cert.subject = OpenSSL::X509::Name.parse("/CN=test")
      cert.issuer = cert.subject
      cert.not_before = Time.now
      cert.not_after = Time.now + 365 * 86_400
      cert.public_key = key.public_key
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
      cert
    end

    it "returns empty hash when no mTLS settings are configured" do
      SiteSetting.openid_connect_mtls_client_cert = ""
      SiteSetting.openid_connect_mtls_client_key = ""
      expect(authenticator.mtls_ssl_options).to eq({})
    end

    it "parses valid PEM certificate and key" do
      SiteSetting.openid_connect_mtls_client_cert = cert.to_pem
      SiteSetting.openid_connect_mtls_client_key = key.to_pem

      result = authenticator.mtls_ssl_options
      expect(result[:client_cert]).to be_a(OpenSSL::X509::Certificate)
      expect(result[:client_key]).to be_a(OpenSSL::PKey::RSA)
    end

    it "raises OpenSSL error for invalid cert PEM" do
      SiteSetting.openid_connect_mtls_client_cert = "not-a-cert"
      SiteSetting.openid_connect_mtls_client_key = key.to_pem
      Rails.logger.expects(:error).with(includes("Failed to parse mTLS"))
      expect { authenticator.mtls_ssl_options }.to raise_error(OpenSSL::OpenSSLError)
    end

    it "raises OpenSSL error for invalid key PEM" do
      SiteSetting.openid_connect_mtls_client_cert = cert.to_pem
      SiteSetting.openid_connect_mtls_client_key = "not-a-key"
      Rails.logger.expects(:error).with(includes("Failed to parse mTLS"))
      expect { authenticator.mtls_ssl_options }.to raise_error(OpenSSL::OpenSSLError)
    end

    it "decrypts a key with a passcode when the setting is provided" do
      encrypted_key = key.export(OpenSSL::Cipher.new("aes-256-cbc"), "some_passphrase")

      SiteSetting.openid_connect_mtls_client_cert = cert.to_pem
      SiteSetting.openid_connect_mtls_client_key = encrypted_key
      SiteSetting.openid_connect_mtls_client_key_passcode = "some_passphrase"

      result = authenticator.mtls_ssl_options
      expect(result[:client_key]).to be_a(OpenSSL::PKey::RSA)
    end

    it "raises OpenSSL error when the passphrase is wrong" do
      encrypted_key = key.export(OpenSSL::Cipher.new("aes-256-cbc"), "some_passphrase")

      SiteSetting.openid_connect_mtls_client_key = encrypted_key
      SiteSetting.openid_connect_mtls_client_key_passcode = "wrong_passphrase"
      SiteSetting.openid_connect_mtls_client_cert = cert.to_pem
      Rails.logger.expects(:error).with(includes("Failed to parse mTLS"))
      expect { authenticator.mtls_ssl_options }.to raise_error(OpenSSL::OpenSSLError)
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
