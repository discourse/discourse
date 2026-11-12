# frozen_string_literal: true

RSpec.describe JsonApiKit::ApiVersion do
  subject(:version) { described_class.parse(raw) }

  let(:raw) { "2026-09-01" }

  before { freeze_time(Date.new(2027, 1, 20)) }

  describe ".parse" do
    it "returns the version with that date" do
      expect(version.date).to eq(Date.new(2026, 9, 1))
    end

    context "when the date has no day" do
      let(:raw) { "2026-09" }

      it { expect { version }.to raise_error(described_class::NotADate) }
    end

    context "when the date has no separators" do
      let(:raw) { "20260901" }

      it { expect { version }.to raise_error(described_class::NotADate) }
    end

    context "when the date has a time" do
      let(:raw) { "2026-09-01T00:00:00Z" }

      it { expect { version }.to raise_error(described_class::NotADate) }
    end

    context "when the date is not a real date" do
      let(:raw) { "2026-02-30" }

      it { expect { version }.to raise_error(described_class::NotADate) }
    end

    context "when there is no date" do
      let(:raw) { nil }

      it { expect { version }.to raise_error(described_class::NotADate) }
    end
  end

  describe "#eql?" do
    context "when the other version has the same date" do
      let(:other) { described_class.parse("2026-09-01") }

      it { expect(version).to eql(other) }
    end

    context "when the other version has another date" do
      let(:other) { described_class.parse("2026-11-15") }

      it { expect(version).not_to eql(other) }
    end
  end

  describe "#hash" do
    let(:other) { described_class.parse("2026-09-01") }

    it "is the same for two versions of one date" do
      expect(version.hash).to eq(other.hash)
    end
  end

  describe "#<=>" do
    context "when the other version is later" do
      let(:other) { described_class.parse("2026-11-15") }

      it "sorts before it" do
        expect(version).to be < other
      end
    end

    context "when the other is not a version" do
      it "is not equal" do
        expect(version).not_to eq("2026-09-01")
      end
    end

    context "when the other version has the same date" do
      let(:other) { described_class.parse(raw) }

      it "equals it" do
        expect(version).to eq(other)
      end
    end
  end

  describe "#future?" do
    context "when the date is earlier than today" do
      it { is_expected.not_to be_future }
    end

    context "when the date is today" do
      let(:raw) { Time.zone.today.to_s }

      it { is_expected.not_to be_future }
    end

    context "when the date is later than today" do
      let(:raw) { (Time.zone.today + 1.day).to_s }

      it { is_expected.to be_future }
    end
  end

  describe "#to_s" do
    it "returns the date as YYYY-MM-DD" do
      expect(version.to_s).to eq(raw)
    end
  end
end
