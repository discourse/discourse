# frozen_string_literal: true

RSpec.describe JsonApiKit::Timeline do
  let(:earliest) { JsonApiKit::ApiVersion.parse("2026-09-01") }
  let(:middle) { JsonApiKit::ApiVersion.parse("2026-11-15") }
  let(:latest) { JsonApiKit::ApiVersion.parse("2027-01-05") }
  let(:timeline) { described_class.new([earliest, middle, latest].map(&:to_s)) }

  before do
    freeze_time(Date.new(2027, 1, 20))
    allow(described_class).to receive(:core).and_return(timeline)
  end

  describe ".first" do
    it "returns the earliest version" do
      expect(described_class.first).to eq(earliest)
    end
  end

  describe ".current" do
    it "returns the latest version" do
      expect(described_class.current).to eq(latest)
    end
  end

  describe ".resolve" do
    subject(:version) { described_class.resolve(raw) }

    let(:raw) { middle.to_s }

    context "when the date is a published version" do
      it "returns that version" do
        expect(version).to eq(middle)
      end
    end

    context "when the date falls between two versions" do
      let(:raw) { "2026-12-01" }

      it "returns the newest version before it" do
        expect(version).to eq(middle)
      end
    end

    context "when the date is later than every version but not in the future" do
      let(:raw) { "2027-01-10" }

      it "returns the latest version" do
        expect(version).to eq(latest)
      end
    end

    context "when there is no date" do
      let(:raw) { nil }

      it { expect { version }.to raise_error(JsonApiKit::ApiVersion::Required) }
    end

    context "when the date is earlier than the first version" do
      let(:raw) { (earliest.date - 1.day).to_s }

      it { expect { version }.to raise_error(JsonApiKit::ApiVersion::Unknown) }
    end

    context "when the date is in the future" do
      let(:raw) { (Time.zone.today + 1.day).to_s }

      it { expect { version }.to raise_error(JsonApiKit::ApiVersion::InTheFuture) }
    end

    context "when the date is invalid" do
      let(:raw) { "yesterday" }

      it { expect { version }.to raise_error(JsonApiKit::ApiVersion::NotADate) }
    end
  end
end
