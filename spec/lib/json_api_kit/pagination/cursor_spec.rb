# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Cursor do
  subject(:cursor) { described_class.new(values) }

  let(:values) { [42, "alice"] }

  describe ".new" do
    context "with a value that cannot travel in a cursor" do
      let(:values) { [{ id: 1 }] }

      it "refuses to build a cursor" do
        expect { cursor }.to raise_error(described_class::UnsupportedValue)
      end
    end

    context "with a timestamp" do
      let(:values) { [Time.new(2026, 8, 3, 14, 0, 0, "+02:00")] }

      it "leaves the given value untouched" do
        expect { cursor }.not_to change { values.first.utc_offset }
      end
    end
  end

  describe ".parse" do
    subject(:parsed) { described_class.parse(raw) }

    let(:raw) { cursor.to_s }

    it "returns a cursor equal to the one that was encoded" do
      expect(parsed).to eq(cursor)
    end

    context "with a timestamp" do
      let(:values) { [Time.utc(2026, 8, 3, 12, 0, 0, 123_456)] }

      it "round-trips the value exactly" do
        expect(parsed.values).to eq(cursor.values)
      end
    end

    context "when the string is not base64" do
      let(:raw) { "not base64!!" }

      it "rejects the cursor" do
        expect { parsed }.to raise_error(described_class::Invalid)
      end
    end

    context "when the payload is not a list of values" do
      let(:raw) { Base64.urlsafe_encode64(%({"id":1}), padding: false) }

      it "rejects the cursor" do
        expect { parsed }.to raise_error(described_class::Invalid)
      end
    end

    context "when the payload holds a nested value" do
      let(:raw) { Base64.urlsafe_encode64("[[1]]", padding: false) }

      it "rejects the cursor" do
        expect { parsed }.to raise_error(described_class::Invalid)
      end
    end

    context "when the cursor is empty" do
      let(:raw) { "" }

      it "rejects the cursor" do
        expect { parsed }.to raise_error(described_class::Invalid)
      end
    end
  end

  describe "#values" do
    subject(:encoded_values) { cursor.values }

    it "keeps JSON scalars as they are" do
      expect(encoded_values).to eq([42, "alice"])
    end

    context "with a timestamp" do
      let(:values) { [Time.utc(2026, 8, 3, 12, 0, 0, 123_456)] }

      it "keeps microsecond precision" do
        expect(encoded_values).to eq(%w[2026-08-03T12:00:00.123456Z])
      end
    end

    context "with a timestamp in a zone" do
      let(:values) { [Time.utc(2026, 8, 3, 12, 0, 0, 123_456).in_time_zone("Europe/Paris")] }

      it "encodes the instant in UTC" do
        expect(encoded_values).to eq(%w[2026-08-03T12:00:00.123456Z])
      end
    end

    context "with a date" do
      let(:values) { [Date.new(2026, 8, 3)] }

      it "encodes it as an ISO 8601 date" do
        expect(encoded_values).to eq(%w[2026-08-03])
      end
    end

    context "with a decimal" do
      let(:values) { [BigDecimal("1.5")] }

      it "encodes it as a string, so no digit is lost" do
        expect(encoded_values).to eq(%w[1.5])
      end
    end
  end

  describe "#to_s" do
    subject(:encoded) { cursor.to_s }

    it "holds the values as urlsafe base64 JSON" do
      expect(encoded).to eq(Base64.urlsafe_encode64(%([42,"alice"]), padding: false))
    end

    context "when the payload length calls for base64 padding" do
      let(:values) { [12] }

      it "omits the padding" do
        expect(encoded).not_to include("=")
      end
    end
  end

  describe "#size" do
    subject(:size) { cursor.size }

    it "counts the values" do
      expect(size).to eq(2)
    end
  end

  describe "#==" do
    let(:other) { described_class.new(values) }

    it "treats cursors holding the same values as equal" do
      expect(cursor).to eq(other)
    end

    context "with a cursor holding other values" do
      let(:other) { described_class.new([43, "alice"]) }

      it "treats them as different" do
        expect(cursor).not_to eq(other)
      end
    end

    context "with something that is not a cursor" do
      let(:other) { "cursor-ish" }

      it "treats them as different" do
        expect(cursor).not_to eq(other)
      end
    end
  end
end
