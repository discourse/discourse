#frozen_string_literal: true

RSpec.describe Onebox::Engine::VimeoOnebox do
  describe ".===" do
    it "matches valid Vimeo video URL" do
      valid_url = URI("https://vimeo.com/123456789")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid Vimeo video URL with additional segment" do
      valid_url_with_segment = URI("https://vimeo.com/123456789/info")
      expect(described_class === valid_url_with_segment).to eq(true)
    end

    it "does not match URL with invalid path" do
      invalid_path_url = URI("https://vimeo.com/invalid/123456789")
      expect(described_class === invalid_path_url).to eq(false)
    end

    it "does not match unrelated domain" do
      unrelated_url = URI("https://example.com/123456789")
      expect(described_class === unrelated_url).to eq(false)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://vimeo.com.malicious.com/123456789")
      expect(described_class === malicious_url).to eq(false)
    end
  end
end
