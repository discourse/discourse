# frozen_string_literal: true

describe BrowserPageviewEventUrlNormalizer do
  describe ".normalize_referrer" do
    it "returns nil for blank input" do
      expect(described_class.normalize_referrer(nil)).to be_nil
      expect(described_class.normalize_referrer("")).to be_nil
      expect(described_class.normalize_referrer("  ")).to be_nil
    end

    it "returns nil for malformed input or URLs without a host" do
      expect(described_class.normalize_referrer("not a url")).to be_nil
      expect(described_class.normalize_referrer("javascript:alert(1)")).to be_nil
      expect(described_class.normalize_referrer("data:text/html,<x>")).to be_nil
      expect(described_class.normalize_referrer("https://")).to be_nil
      expect(described_class.normalize_referrer("file:///etc/passwd")).to be_nil
    end

    it "strips scheme, lowercases host, strips www and trailing dot" do
      expect(described_class.normalize_referrer("https://www.Example.com/path")).to eq(
        "example.com/path",
      )
      expect(described_class.normalize_referrer("HTTP://EXAMPLE.COM/Path")).to eq(
        "example.com/Path",
      )
      expect(described_class.normalize_referrer("https://example.com./path")).to eq(
        "example.com/path",
      )
    end

    it "strips the port from any host" do
      expect(described_class.normalize_referrer("https://example.com:3000/path")).to eq(
        "example.com/path",
      )
      expect(described_class.normalize_referrer("https://example.com:443/path")).to eq(
        "example.com/path",
      )
      expect(described_class.normalize_referrer("https://example.com:80")).to eq("example.com")
    end

    it "strips fragment" do
      expect(described_class.normalize_referrer("https://example.com/path#section")).to eq(
        "example.com/path",
      )
    end

    it "strips trailing slash on path" do
      expect(described_class.normalize_referrer("https://example.com/path/")).to eq(
        "example.com/path",
      )
      expect(described_class.normalize_referrer("https://example.com/")).to eq("example.com")
    end

    it "strips multiple trailing slashes" do
      expect(described_class.normalize_referrer("https://example.com/path//")).to eq(
        "example.com/path",
      )
      expect(described_class.normalize_referrer("https://example.com/path///")).to eq(
        "example.com/path",
      )
      expect(described_class.normalize_referrer("https://example.com///")).to eq("example.com")
    end

    it "collapses IDN and punycode forms to the same host" do
      unicode = described_class.normalize_referrer("https://münchen.de/foo")
      punycode = described_class.normalize_referrer("https://xn--mnchen-3ya.de/foo")
      expect(unicode).to eq(punycode)
      expect(unicode).to eq("xn--mnchen-3ya.de/foo")
    end

    it "drops tracking query params but keeps others" do
      expect(described_class.normalize_referrer("https://example.com/p?utm_source=x&id=42")).to eq(
        "example.com/p?id=42",
      )
      expect(
        described_class.normalize_referrer(
          "https://news.ycombinator.com/item?id=12345&utm_campaign=x",
        ),
      ).to eq("news.ycombinator.com/item?id=12345")
      expect(described_class.normalize_referrer("https://example.com/p?utm_source=x")).to eq(
        "example.com/p",
      )
      expect(
        described_class.normalize_referrer("https://example.com/p?fbclid=abc&gclid=def"),
      ).to eq("example.com/p")
    end

    it "preserves original query encoding (does not re-encode)" do
      expect(described_class.normalize_referrer("https://example.com/p?q=foo%20bar")).to eq(
        "example.com/p?q=foo%20bar",
      )
      expect(described_class.normalize_referrer("https://example.com/p?q=foo+bar")).to eq(
        "example.com/p?q=foo+bar",
      )
    end

    it "preserves query order and duplicates among kept params" do
      expect(described_class.normalize_referrer("https://example.com/p?a=1&b=2&a=3")).to eq(
        "example.com/p?a=1&b=2&a=3",
      )
    end

    it "truncates to 2000 bytes and produces valid UTF-8" do
      long_path = "x" * 2200
      result = described_class.normalize_referrer("https://example.com/#{long_path}")
      expect(result.bytesize).to be <= 2000
      expect(result).to be_valid_encoding
    end

    it "scrubs invalid bytes left by mid-character truncation" do
      multibyte = "ü" * 1100
      result = described_class.normalize_referrer("https://example.com/#{multibyte}")
      expect(result.bytesize).to be <= 2000
      expect(result).to be_valid_encoding
    end
  end

  describe ".normalize_host" do
    it "lowercases, strips www prefix, and strips trailing dot" do
      expect(described_class.normalize_host("Forum.Example.Com")).to eq("forum.example.com")
      expect(described_class.normalize_host("www.example.com")).to eq("example.com")
      expect(described_class.normalize_host("example.com.")).to eq("example.com")
    end

    it "converts Unicode hosts to punycode" do
      expect(described_class.normalize_host("münchen.de")).to eq("xn--mnchen-3ya.de")
      expect(described_class.normalize_host("xn--mnchen-3ya.de")).to eq("xn--mnchen-3ya.de")
    end

    it "returns nil for blank input" do
      expect(described_class.normalize_host(nil)).to be_nil
      expect(described_class.normalize_host("")).to be_nil
    end
  end

  describe ".normalize_site_path" do
    it "returns a canonical site-relative path" do
      expect(
        described_class.normalize_site_path("https://forum.example/latest/?sort=recent#section"),
      ).to eq("/latest")
      expect(described_class.normalize_site_path("/top?sort=popular")).to eq("/top")
      expect(described_class.normalize_site_path("about/")).to eq("/about")
      expect(described_class.normalize_site_path("https://forum.example/")).to eq("/")
    end

    it "returns nil for an unusable URL" do
      expect(described_class.normalize_site_path(nil)).to be_nil
      expect(described_class.normalize_site_path("javascript:alert(1)")).to be_nil
    end
  end
end
