# frozen_string_literal: true

RSpec.describe Onebox::Engine::SoundCloudOnebox do
  describe ".===" do
    it "matches valid SoundCloud URL" do
      valid_url = URI("https://soundcloud.com/artist/track")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid SoundCloud URL with additional path" do
      valid_url_with_path = URI("https://soundcloud.com/artist/track/more-info")
      expect(described_class === valid_url_with_path).to eq(true)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("https://soundcloud.com.malicious.com/artist/track")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match URL with subdomain" do
      subdomain_url = URI("https://sub.soundcloud.com/artist/track")
      expect(described_class === subdomain_url).to eq(false)
    end

    it "does not match unrelated URL" do
      unrelated_url = URI("https://example.com/soundcloud.com/artist/track")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
