# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Cursor do
  subject(:cursor) { described_class.new(values) }

  let(:values) { [42, "alice"] }

  describe ".new" do
    context "when the cursor cannot encode a value" do
      let(:values) { [{ id: 1 }] }

      it "refuses to build the cursor" do
        expect { cursor }.to raise_error(described_class::UnsupportedValue)
      end
    end

    context "when the cursor holds a timestamp" do
      let(:values) { [Time.new(2026, 8, 3, 14, 0, 0, "+02:00")] }

      it "does not change the timestamp it encodes" do
        expect { cursor }.not_to change { values.first.utc_offset }
      end
    end
  end

  describe ".valid?" do
    subject { described_class }

    let(:wire_cursor) { cursor.to_s }

    it { is_expected.to be_valid(wire_cursor) }

    context "when the string is no cursor" do
      let(:wire_cursor) { "not base64!!" }

      it { is_expected.not_to be_valid(wire_cursor) }
    end
  end

  describe ".parse" do
    subject(:parsed_cursor) { described_class.parse(wire_cursor) }

    let(:wire_cursor) { cursor.to_s }

    it "returns a cursor equal to the one that wrote the string" do
      expect(parsed_cursor).to eq(cursor)
    end

    context "when the cursor holds a timestamp" do
      let(:values) { [Time.utc(2026, 8, 3, 12, 0, 0, 123_456)] }

      it "returns the same values" do
        expect(parsed_cursor.values).to eq(cursor.values)
      end
    end

    context "when the string is not base64" do
      let(:wire_cursor) { "not base64!!" }

      it "refuses the string" do
        expect { parsed_cursor }.to raise_error(ArgumentError)
      end
    end

    context "when the string holds no list of values" do
      let(:wire_cursor) { Base64.urlsafe_encode64(%({"id":1}), padding: false) }

      it "refuses the string" do
        expect { parsed_cursor }.to raise_error(ArgumentError)
      end
    end

    context "when the list holds another list" do
      let(:wire_cursor) { Base64.urlsafe_encode64("[[1]]", padding: false) }

      it "refuses the string" do
        expect { parsed_cursor }.to raise_error(ArgumentError)
      end
    end

    context "when the string is empty" do
      let(:wire_cursor) { "" }

      it "refuses the string" do
        expect { parsed_cursor }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#values" do
    subject(:encoded_values) { cursor.values }

    context "when the cursor holds a number and a string" do
      it "keeps both as they are" do
        expect(encoded_values).to eq([42, "alice"])
      end
    end

    context "when the cursor holds nil, true or false" do
      let(:values) { [nil, true, false] }

      it "keeps each one as it is" do
        expect(encoded_values).to eq([nil, true, false])
      end
    end

    context "when the cursor holds a timestamp" do
      let(:values) { [Time.utc(2026, 8, 3, 12, 0, 0, 123_456)] }

      it "encodes it to the microsecond" do
        expect(encoded_values).to eq(%w[2026-08-03T12:00:00.123456Z])
      end
    end

    context "when the timestamp carries a zone" do
      let(:values) { [Time.utc(2026, 8, 3, 12, 0, 0, 123_456).in_time_zone("Europe/Paris")] }

      it "encodes the same instant in UTC" do
        expect(encoded_values).to eq(%w[2026-08-03T12:00:00.123456Z])
      end
    end

    context "when the cursor holds a date" do
      let(:values) { [Date.new(2026, 8, 3)] }

      it "encodes it as an ISO 8601 date" do
        expect(encoded_values).to eq(%w[2026-08-03])
      end
    end

    context "when the cursor holds a decimal" do
      let(:values) { [BigDecimal("1.5")] }

      it "encodes it as a string" do
        expect(encoded_values).to eq(%w[1.5])
      end
    end
  end

  describe "#to_s" do
    subject(:encoded_cursor) { cursor.to_s }

    it "encodes the values as urlsafe base64 JSON" do
      expect(encoded_cursor).to eq(Base64.urlsafe_encode64(%([42,"alice"]), padding: false))
    end

    context "when base64 would pad the string" do
      let(:values) { [12] }

      it "leaves the padding out" do
        expect(encoded_cursor).not_to include("=")
      end
    end
  end

  describe "#size" do
    subject(:size) { cursor.size }

    it "returns the number of values" do
      expect(size).to eq(2)
    end
  end

  describe "#==" do
    let(:other_cursor) { described_class.new(values) }

    context "when the other cursor holds the same values" do
      it "equals the other cursor" do
        expect(cursor).to eq(other_cursor)
      end
    end

    context "when the other cursor holds other values" do
      let(:other_cursor) { described_class.new([43, "alice"]) }

      it "differs from the other cursor" do
        expect(cursor).not_to eq(other_cursor)
      end
    end

    context "when the other object is no cursor" do
      let(:other_cursor) { "cursor-ish" }

      it "differs from the other object" do
        expect(cursor).not_to eq(other_cursor)
      end
    end
  end
end
