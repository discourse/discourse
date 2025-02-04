# frozen_string_literal: true

RSpec.describe Onebox::Engine::PastebinOnebox do
  describe ".===" do
    it "matches valid Pastebin URL" do
      valid_url = URI("http://pastebin.com/abc123")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid Pastebin URL with HTTPS" do
      valid_https_url = URI("https://pastebin.com/abc123")
      expect(described_class === valid_https_url).to eq(true)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("http://pastebin.com.malicious.com/abc123")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match URL with subdomain" do
      subdomain_url = URI("http://sub.pastebin.com/abc123")
      expect(described_class === subdomain_url).to eq(false)
    end

    it "does not match unrelated URL" do
      unrelated_url = URI("http://example.com/pastebin.com/abc123")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
