# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::FeedUrl do
  describe ".redact" do
    it "removes api_key and api_username from the query" do
      redacted =
        described_class.redact(
          "https://example.com/feed?api_key=secret&api_username=system&foo=bar",
        )

      expect(redacted).to eq("https://example.com/feed?foo=bar")
      expect(redacted).not_to include("secret")
      expect(redacted).not_to include("system")
    end

    it "drops the query entirely when only credentials are present" do
      expect(described_class.redact("https://example.com/feed?api_key=secret")).to eq(
        "https://example.com/feed",
      )
    end

    it "leaves a credential-free url untouched" do
      expect(described_class.redact("https://example.com/feed")).to eq("https://example.com/feed")
    end

    it "does not leak credentials when the url is malformed" do
      expect(described_class.redact("https://exa mple.com/feed?api_key=secret")).not_to include(
        "secret",
      )
    end

    it "handles blank input" do
      expect(described_class.redact(nil)).to eq("")
    end
  end

  describe ".http?" do
    it "is true for http and https urls (any case)" do
      expect(described_class.http?("http://example.com/feed")).to eq(true)
      expect(described_class.http?("https://example.com/feed")).to eq(true)
      expect(described_class.http?("HTTPS://example.com/feed")).to eq(true)
    end

    it "is false for other schemes, scheme-less urls, and blank input" do
      expect(described_class.http?("javascript:alert(1)")).to eq(false)
      expect(described_class.http?("ftp://example.com/feed")).to eq(false)
      expect(described_class.http?("example.com/feed")).to eq(false)
      expect(described_class.http?("")).to eq(false)
      expect(described_class.http?(nil)).to eq(false)
    end
  end
end
