# frozen_string_literal: true

RSpec.describe DiscourseCalendar::Livestream::AllowedHosts do
  describe ".allows_url?" do
    it "accepts a host on the default list and its subdomains" do
      expect(described_class.allows_url?("https://www.youtube.com/watch?v=abc")).to eq(true)
      expect(described_class.allows_url?("https://youtu.be/abc")).to eq(true)
      expect(described_class.allows_url?("https://us06web.zoom.us/j/123456789")).to eq(true)
      expect(described_class.allows_url?("https://twitch.tv/username")).to eq(true)
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
      expect(described_class.allows_url?("https://youtube.com%5C@evil.com/live")).to eq(false)
      expect(described_class.allows_url?("https://youtube.com\t@evil.com/live")).to eq(false)
      expect(described_class.allows_url?("https://youtube.com\n@evil.com/live")).to eq(false)
    end

    # The browser resolves these to a host the admin did allow, so the editor
    # offers the livestream toggle for them and the save path has to agree.
    it "matches the host the browser would connect to" do
      expect(described_class.allows_url?("https://youtube.com\\@evil.com/live")).to eq(true)
      expect(described_class.allows_url?("https://%79outube.com/live")).to eq(true)
      expect(described_class.allows_url?("https://ｙoutube.com/live")).to eq(true)
      expect(described_class.allows_url?("https://youtube.com./live")).to eq(true)
    end

    it "rejects a separator that only looks like a label boundary" do
      expect(described_class.allows_url?("https://youtube.com。evil.com/live")).to eq(false)
      expect(described_class.allows_url?("https://youtube.com%2eevil.com/live")).to eq(false)
    end

    it "rejects anything that is not an https URL" do
      expect(described_class.allows_url?("youtube.com/watch?v=abc")).to eq(false)
      expect(described_class.allows_url?("http://youtube.com/watch")).to eq(false)
      expect(described_class.allows_url?("ftp://youtube.com/watch")).to eq(false)
      expect(described_class.allows_url?("//youtube.com/watch")).to eq(false)
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
  end

  describe ".list" do
    it "returns the configured hosts" do
      SiteSetting.livestream_allowed_hosts = "youtube.com|zoom.us"

      expect(described_class.list).to eq(%w[youtube.com zoom.us])
    end
  end

  describe ".normalize" do
    it "canonicalizes an entry to the host a browser resolves" do
      expect(described_class.normalize("YOUTUBE.com")).to eq("youtube.com")
      expect(described_class.normalize(" zoom.us ")).to eq("zoom.us")
    end

    it "takes an international host in the punycode it is compared as" do
      expect(described_class.normalize("xn--80ak6aa92e.com")).to eq("xn--80ak6aa92e.com")
      expect(described_class.normalize("ｙoutube.com")).to be_nil
    end

    it "rejects an entry that is not a bare host" do
      expect(described_class.normalize("https://vimeo.com/videos")).to be_nil
      expect(described_class.normalize("vimeo.com/videos")).to be_nil
      expect(described_class.normalize("vimeo.com:443")).to be_nil
      expect(described_class.normalize("youtube.com@evil.com")).to be_nil
      expect(described_class.normalize("youtube.com。evil.com")).to be_nil
      expect(described_class.normalize("")).to be_nil
      expect(described_class.normalize(nil)).to be_nil
    end
  end
end
