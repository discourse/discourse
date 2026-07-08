# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::ApiVersion do
  describe ".parse" do
    it "parses a YYYY-MM-DD string" do
      expect(described_class.parse("2026-06-15").to_s).to eq("2026-06-15")
    end

    it "rejects a malformed string" do
      expect { described_class.parse("garbage") }.to raise_error(described_class::Invalid)
    end

    it "rejects a non-zero-padded date" do
      expect { described_class.parse("2026-6-15") }.to raise_error(described_class::Invalid)
    end

    it "rejects an impossible date" do
      expect { described_class.parse("2026-13-45") }.to raise_error(described_class::Invalid)
    end

    it "rejects nil" do
      expect { described_class.parse(nil) }.to raise_error(described_class::Invalid)
    end
  end

  describe "comparison" do
    it "orders versions chronologically" do
      versions = %w[2026-06-15 2026-05-01 2026-07-01].map { described_class.parse(it) }

      expect(versions.sort.map(&:to_s)).to eq(%w[2026-05-01 2026-06-15 2026-07-01])
    end

    it "treats two versions with the same date as the same hash key" do
      versions = [described_class.parse("2026-05-01"), described_class.parse("2026-05-01")]

      expect(versions.uniq.size).to eq(1)
    end
  end

  describe "#future?" do
    subject(:version) { described_class.parse("2026-06-15") }

    it "is true when the date is after today" do
      expect(version.future?(today: Date.parse("2026-06-14"))).to be(true)
    end

    it "is false when the date is today" do
      expect(version.future?(today: Date.parse("2026-06-15"))).to be(false)
    end
  end
end
