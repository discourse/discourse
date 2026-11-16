# frozen_string_literal: true

RSpec.describe HostnameNormalizer do
  describe ".normalize" do
    it "lowercases and strips an optional trailing root-label dot" do
      expect(described_class.normalize("API.CAT.ORG.")).to eq("api.cat.org")
    end

    it "collapses repeated trailing root-label dots" do
      expect(described_class.normalize("api.cat.org...")).to eq("api.cat.org")
    end

    it "trims surrounding whitespace" do
      expect(described_class.normalize("  api.cat.org.  ")).to eq("api.cat.org")
    end

    it "keeps a single-label hostname intact once the root dot is removed" do
      expect(described_class.normalize("localhost.")).to eq("localhost")
    end

    it "returns an empty string for nil" do
      expect(described_class.normalize(nil)).to eq("")
    end

    it "returns an empty string for a bare root dot" do
      expect(described_class.normalize(".")).to eq("")
    end

    it "converts a Unicode label to its punycode form" do
      expect(described_class.normalize("exämple.com")).to eq("xn--exmple-cua.com")
    end

    it "never raises for values that are not valid hostnames" do
      expect { described_class.normalize("not a host °") }.not_to raise_error
    end
  end

  describe ".normalize_list" do
    it "normalizes each pipe-separated entry and drops surrounding whitespace" do
      expect(described_class.normalize_list(" A.ORG. |b.com ")).to eq(%w[a.org b.com])
    end

    it "returns an empty array for an empty string" do
      expect(described_class.normalize_list("")).to eq([])
    end

    it "returns nil for nil" do
      expect(described_class.normalize_list(nil)).to be_nil
    end
  end

  describe ".equivalent?" do
    it "matches across case and a trailing root-label dot" do
      expect(described_class.equivalent?("API.CAT.ORG", "api.cat.org.")).to be(true)
    end

    it "matches a Unicode hostname against its punycode form" do
      expect(described_class.equivalent?("exämple.com", "xn--exmple-cua.com")).to be(true)
    end

    it "does not match a subdomain against its parent" do
      expect(described_class.equivalent?("dev.api.cat.org", "api.cat.org")).to be(false)
    end

    it "is false when both inputs normalize to empty" do
      expect(described_class.equivalent?("", ".")).to be(false)
    end
  end

  describe ".within?" do
    it "matches a subdomain across case and a trailing root-label dot" do
      expect(described_class.within?("dev.api.cat.org.", "API.CAT.ORG")).to be(true)
    end

    it "does not widen scope to a label boundary that is not a dot" do
      expect(described_class.within?("xapi.cat.org", "api.cat.org")).to be(false)
    end

    it "is false when the domain is empty" do
      expect(described_class.within?("api.cat.org", "")).to be(false)
    end
  end
end
