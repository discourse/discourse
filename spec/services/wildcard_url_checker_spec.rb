# frozen_string_literal: true

RSpec.describe WildcardUrlChecker do
  describe ".check_url" do
    subject(:check) { described_class.check_url(pattern, url) }

    context "when pattern is *" do
      let(:pattern) { "*" }
      let(:url) { "https://hello.discourse.org" }

      it { is_expected.to eq(true) }
    end

    context "with exact URL match" do
      let(:pattern) { "https://www.discourse.org" }

      it "matches the same URL" do
        expect(described_class.check_url(pattern, "https://www.discourse.org")).to eq(true)
      end

      it "does not match a different subdomain" do
        expect(described_class.check_url(pattern, "https://www.www.discourse.org")).to eq(false)
      end

      it "does not match when the domain is used as a path component" do
        expect(described_class.check_url(pattern, "https://evil.com/www.discourse.org")).to eq(
          false,
        )
      end

      it "does not match a URL with the domain appended to an attacker domain" do
        expect(described_class.check_url(pattern, "https://www.discourse.org.evil.com")).to eq(
          false,
        )
      end

      it "does not match a URL with an embedded newline" do
        expect(
          described_class.check_url(
            pattern,
            "https://www.discourse.org\nwww.discourse.org.evil.com",
          ),
        ).to eq(false)
      end
    end

    context "with a subdomain wildcard pattern (*.example.com)" do
      let(:pattern) { "https://*.example.com/callback" }

      it "matches a direct subdomain" do
        expect(described_class.check_url(pattern, "https://app.example.com/callback")).to eq(true)
      end

      it "matches a deeply nested subdomain" do
        expect(described_class.check_url(pattern, "https://deep.sub.example.com/callback")).to eq(
          true,
        )
      end

      it "does not match the apex domain" do
        expect(described_class.check_url(pattern, "https://example.com/callback")).to eq(false)
      end

      it "does not match a different path" do
        expect(described_class.check_url(pattern, "https://app.example.com/other")).to eq(false)
      end

      it "does not match when the domain appears only in the path" do
        expect(
          described_class.check_url(pattern, "https://evil.com/path/.example.com/callback"),
        ).to eq(false)
      end

      it "does not match a domain that ends with example.com but is not a subdomain" do
        expect(described_class.check_url(pattern, "https://notexample.com/callback")).to eq(false)
      end

      it "does not match a domain that uses example.com as a suffix on an attacker domain" do
        expect(
          described_class.check_url(pattern, "https://evil.com.example.com.attacker.com/callback"),
        ).to eq(false)
      end

      it "does not match a different scheme" do
        expect(described_class.check_url(pattern, "http://app.example.com/callback")).to eq(false)
      end

      it "does not match a different port" do
        expect(described_class.check_url(pattern, "https://app.example.com:8080/callback")).to eq(
          false,
        )
      end
    end

    context "with a wildcard in the path" do
      let(:pattern) { "https://*.example.com/*" }

      it "matches any path on a valid subdomain" do
        expect(described_class.check_url(pattern, "https://app.example.com/any/path")).to eq(true)
      end

      it "still does not match a different host even with path wildcards" do
        expect(described_class.check_url(pattern, "https://evil.com/any.example.com/path")).to eq(
          false,
        )
      end
    end

    context "with a custom protocol" do
      let(:pattern) { "discourse://auth_redirect" }
      let(:url) { "discourse://auth_redirect" }

      it { is_expected.to eq(true) }
    end

    context "with invalid URLs" do
      it "returns false for URLs with no host" do
        expect(described_class.check_url("https://", "https://")).to eq(false)
      end

      it "returns false for URLs with no scheme" do
        expect(described_class.check_url("noscheme", "noscheme")).to eq(false)
      end

      it "returns false for URLs with an invalid scheme character in the pattern" do
        expect(
          described_class.check_url(
            "invalid$protocol://www.discourse.org",
            "invalid$protocol://www.discourse.org",
          ),
        ).to eq(false)
      end
    end
  end
end
