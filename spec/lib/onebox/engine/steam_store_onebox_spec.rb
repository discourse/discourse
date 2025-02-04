#frozen_string_literal: true

RSpec.describe Onebox::Engine::SteamStoreOnebox do
  describe ".===" do
    it "matches valid Steam Store app URL" do
      valid_url = URI("https://store.steampowered.com/app/123456")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match URL with invalid path" do
      invalid_path_url = URI("https://store.steampowered.com/invalid/123456")
      expect(described_class === invalid_path_url).to eq(false)
    end

    it "does not match unrelated domain" do
      unrelated_url = URI("https://example.com/app/123456")
      expect(described_class === unrelated_url).to eq(false)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("https://store.steampowered.com.malicious.com/app/123456")
      expect(described_class === malicious_url).to eq(false)
    end
  end
end
