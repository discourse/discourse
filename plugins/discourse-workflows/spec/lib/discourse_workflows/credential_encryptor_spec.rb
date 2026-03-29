# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::CredentialEncryptor do
  describe ".encrypt" do
    it "returns an encrypted string that is not the original JSON" do
      data = { "user" => "admin", "password" => "secret123" }
      encrypted = described_class.encrypt(data)

      expect(encrypted).to be_a(String)
      expect(encrypted).not_to include("secret123")
    end
  end

  describe ".decrypt" do
    it "round-trips through encrypt and decrypt" do
      data = { "user" => "admin", "password" => "secret123" }
      encrypted = described_class.encrypt(data)
      decrypted = described_class.decrypt(encrypted)

      expect(decrypted).to eq(data)
    end

    it "raises on tampered data" do
      encrypted = described_class.encrypt({ "x" => "y" })
      expect { described_class.decrypt(encrypted + "tampered") }.to raise_error(
        ActiveSupport::MessageEncryptor::InvalidMessage,
      )
    end
  end
end
