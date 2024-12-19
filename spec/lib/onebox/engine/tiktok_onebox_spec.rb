#frozen_string_literal: true

RSpec.describe Onebox::Engine::TiktokOnebox do
  describe ".===" do
    it "matches valid TikTok user video URL" do
      valid_user_video_url = URI("https://www.tiktok.com/@user123/video/1234567890")
      expect(described_class === valid_user_video_url).to eq(true)
    end

    it "matches valid TikTok short video URL" do
      valid_short_video_url = URI("https://www.tiktok.com/v/1234567890")
      expect(described_class === valid_short_video_url).to eq(true)
    end

    it "does not match URL with invalid path" do
      invalid_path_url = URI("https://www.tiktok.com/@user123/invalid/1234567890")
      expect(described_class === invalid_path_url).to eq(false)
    end

    it "does not match unrelated domain" do
      unrelated_url = URI("https://example.com/@user123/video/1234567890")
      expect(described_class === unrelated_url).to eq(false)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://www.tiktok.com.malicious.com/@user123/video/1234567890")
      expect(described_class === malicious_url).to eq(false)
    end
  end
end
