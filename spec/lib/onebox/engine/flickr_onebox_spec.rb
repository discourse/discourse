# frozen_string_literal: true

RSpec.describe Onebox::Engine::FlickrOnebox do
  describe ".===" do
    it "matches valid Flickr photos URL" do
      valid_url = URI("https://www.flickr.com/photos/username/123456/")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://www.flickr.com.malicious.com/photos/username/123456/")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match invalid path" do
      invalid_path_url = URI("https://www.flickr.com/invalid/123456/")
      expect(described_class === invalid_path_url).to eq(false)
    end
  end
end
