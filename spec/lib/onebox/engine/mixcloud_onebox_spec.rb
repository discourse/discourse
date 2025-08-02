# frozen_string_literal: true

RSpec.describe Onebox::Engine::MixcloudOnebox do
  describe ".===" do
    it "matches valid MixCloud URL" do
      valid_url = URI("https://www.mixcloud.com/user/show-name/")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid MixCloud root URL" do
      valid_url_root = URI("https://www.mixcloud.com/")
      expect(described_class === valid_url_root).to eq(true)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://www.mixcloud.com.malicious.com/user/show-name/")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match unrelated domain" do
      unrelated_url = URI("https://example.com/user/show-name/")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
