# frozen_string_literal: true

RSpec.describe DiscourseId do
  describe ".provider_url" do
    it "returns the default URL when setting is blank" do
      SiteSetting.discourse_id_provider_url = ""
      expect(described_class.provider_url).to eq("https://id.discourse.com")
    end

    it "returns the default URL when setting is nil" do
      SiteSetting.discourse_id_provider_url = nil
      expect(described_class.provider_url).to eq("https://id.discourse.com")
    end

    it "returns the configured URL when setting is present" do
      SiteSetting.discourse_id_provider_url = "https://custom.example.com"
      expect(described_class.provider_url).to eq("https://custom.example.com")
    end
  end

  describe ".masked_client_id" do
    it "returns nil when client_id is blank" do
      SiteSetting.discourse_id_client_id = ""
      expect(described_class.masked_client_id).to be_nil
    end

    it "returns nil when client_id is nil" do
      SiteSetting.discourse_id_client_id = nil
      expect(described_class.masked_client_id).to be_nil
    end

    it "returns the full client_id when it is 12 characters or less" do
      SiteSetting.discourse_id_client_id = "abc123"
      expect(described_class.masked_client_id).to eq("abc123")
    end

    it "returns the full client_id when it is exactly 12 characters" do
      SiteSetting.discourse_id_client_id = "123456789012"
      expect(described_class.masked_client_id).to eq("123456789012")
    end

    it "masks the client_id when it is longer than 12 characters" do
      SiteSetting.discourse_id_client_id = "1234567890123456"
      expect(described_class.masked_client_id).to eq("12345678...3456")
    end

    it "masks a typical UUID-style client_id correctly" do
      SiteSetting.discourse_id_client_id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
      expect(described_class.masked_client_id).to eq("a1b2c3d4...7890")
    end
  end
end
