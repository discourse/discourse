# frozen_string_literal: true

RSpec.describe DiscourseCalendar::Livestream::AllowedHosts do
  describe ".allows_url?" do
    it "accepts a host on the default list and its subdomains" do
      expect(described_class.allows_url?("https://www.youtube.com/watch?v=abc")).to eq(true)
      expect(described_class.allows_url?("https://youtu.be/abc")).to eq(true)
      expect(described_class.allows_url?("https://us06web.zoom.us/j/123456789")).to eq(true)
      expect(described_class.allows_url?("http://twitch.tv/username")).to eq(true)
    end

    it "is case-insensitive" do
      expect(described_class.allows_url?("HTTPS://US06WEB.ZOOM.US/j/123456789")).to eq(true)
    end

    it "rejects a host that is not listed" do
      expect(described_class.allows_url?("https://example.com/live")).to eq(false)
    end

    it "rejects hosts that merely resemble a listed host" do
      expect(described_class.allows_url?("https://notzoom.us/j/123456789")).to eq(false)
      expect(described_class.allows_url?("https://zoom.us.evil.com/j/123456789")).to eq(false)
      expect(described_class.allows_url?("https://myyoutube.com/watch?v=abc")).to eq(false)
    end

    it "rejects a listed host smuggled into the userinfo" do
      expect(described_class.allows_url?("https://youtube.com@evil.com/live")).to eq(false)
    end

    it "rejects anything that is not an http(s) URL" do
      expect(described_class.allows_url?("youtube.com/watch?v=abc")).to eq(false)
      expect(described_class.allows_url?("ftp://youtube.com/watch")).to eq(false)
      expect(described_class.allows_url?("Room 5")).to eq(false)
      expect(described_class.allows_url?("https://")).to eq(false)
      expect(described_class.allows_url?(nil)).to eq(false)
    end

    it "follows the site setting" do
      SiteSetting.livestream_allowed_hosts = "stream.example.com"

      expect(described_class.allows_url?("https://stream.example.com/live")).to eq(true)
      expect(described_class.allows_url?("https://cdn.stream.example.com/live")).to eq(true)
      expect(described_class.allows_url?("https://www.youtube.com/watch?v=abc")).to eq(false)
    end

    it "allows nothing when the setting is empty" do
      SiteSetting.livestream_allowed_hosts = ""

      expect(described_class.allows_url?("https://www.youtube.com/watch?v=abc")).to eq(false)
    end

    it "tolerates a pasted URL as a list entry" do
      SiteSetting.livestream_allowed_hosts = "https://VIMEO.com/videos"

      expect(described_class.allows_url?("https://vimeo.com/123")).to eq(true)
    end
  end

  describe ".list" do
    it "returns the configured hosts" do
      SiteSetting.livestream_allowed_hosts = "youtube.com|zoom.us"

      expect(described_class.list).to eq(%w[youtube.com zoom.us])
    end
  end
end
