# frozen_string_literal: true

RSpec.describe Onebox::Engine::FiveHundredPxOnebox do
  describe ".===" do
    it "matches valid 500px photo URL" do
      valid_url = URI("https://500px.com/photo/123456/")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://500px.com.malicious.com/photo/123456/")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match invalid path" do
      invalid_path_url = URI("https://500px.com/invalid/123456/")
      expect(described_class === invalid_path_url).to eq(false)
    end
  end
end
