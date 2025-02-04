# frozen_string_literal: true

RSpec.describe Onebox::Engine::FlickrShortenedOnebox do
  describe ".===" do
    it "matches valid Flickr shortened URL" do
      valid_url = URI("https://flic.kr/p/123abc")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://flic.kr.malicious.com/p/123abc")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match invalid path" do
      invalid_path_url = URI("https://flic.kr/invalid/123abc")
      expect(described_class === invalid_path_url).to eq(false)
    end
  end
end
