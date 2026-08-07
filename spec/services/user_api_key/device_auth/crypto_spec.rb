# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::Crypto do
  let(:key) { OpenSSL::PKey::RSA.new(2048) }
  let(:public_key_pem) { key.public_key.to_pem }

  describe ".parse_public_key!" do
    it "parses RSA public keys" do
      expect(described_class.parse_public_key!(public_key_pem)).to be_a(OpenSSL::PKey::RSA)
    end

    it "raises an invalid parameter error for invalid keys" do
      expect { described_class.parse_public_key!("not a key") }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end

  describe ".validate_payload_size!" do
    it "allows payloads that fit the key and padding" do
      expect { described_class.validate_payload_size!("short", key.public_key) }.not_to raise_error
    end

    it "raises when payloads are too large" do
      expect { described_class.validate_payload_size!("x" * 300, key.public_key) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end

  describe ".encrypt!" do
    it "encrypts using the requested padding" do
      encrypted = described_class.encrypt!(key.public_key, "secret", padding: "oaep")

      expect(encrypted).to be_present
      expect(encrypted).not_to eq("secret")
    end

    it "raises an invalid parameter error when encryption fails" do
      public_key = key.public_key
      allow(public_key).to receive(:encrypt).and_raise(OpenSSL::PKey::PKeyError)

      expect { described_class.encrypt!(public_key, "secret") }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end
end
