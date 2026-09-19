# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Cursor do
  subject(:cursor) { described_class.new(values) }

  let(:values) { [42, "alice"] }

  describe ".coerce" do
    subject(:cursor_value) { described_class.coerce(value) }

    context "with a number" do
      let(:value) { 42 }

      it { is_expected.to eq(42) }
    end

    context "with a string" do
      let(:value) { "alice" }

      it { is_expected.to eq("alice") }
    end

    context "with nil" do
      let(:value) { nil }

      it { is_expected.to be_nil }
    end

    context "with a boolean" do
      let(:value) { false }

      it { is_expected.to be(false) }
    end

    context "with a timestamp" do
      let(:value) { Time.utc(2026, 8, 3, 12, 0, 0, 123_456) }

      it "writes it to the microsecond" do
        expect(cursor_value).to eq("2026-08-03T12:00:00.123456Z")
      end
    end

    context "when the timestamp carries a zone" do
      let(:value) { Time.utc(2026, 8, 3, 12, 0, 0, 123_456).in_time_zone("Europe/Paris") }

      it "writes the same instant in UTC" do
        expect(cursor_value).to eq("2026-08-03T12:00:00.123456Z")
      end

      it "leaves the timestamp it reads alone" do
        expect { cursor_value }.not_to change { value.utc_offset }
      end
    end

    context "with a date" do
      let(:value) { Date.new(2026, 8, 3) }

      it "writes it as an ISO 8601 date" do
        expect(cursor_value).to eq("2026-08-03")
      end
    end

    context "with a decimal" do
      let(:value) { BigDecimal("1.5") }

      it "writes it as a string" do
        expect(cursor_value).to eq("1.5")
      end
    end

    context "with a value no cursor can carry" do
      let(:value) { { id: 1 } }

      it "refuses the value" do
        expect { cursor_value }.to raise_error(described_class::UnsupportedValue)
      end
    end

    context "with a value a cursor already carries" do
      let(:value) { described_class.coerce(Time.utc(2026, 8, 3, 12, 0, 0, 123_456)) }

      it "returns it unchanged" do
        expect(cursor_value).to eq("2026-08-03T12:00:00.123456Z")
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

  describe "#to_s" do
    subject(:written_cursor) { cursor.to_s }

    it "writes the values as urlsafe base64 JSON" do
      expect(written_cursor).to eq(Base64.urlsafe_encode64(%([42,"alice"]), padding: false))
    end

    context "when base64 would pad the string" do
      let(:values) { [12] }

      it "leaves the padding out" do
        expect(written_cursor).not_to include("=")
      end
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
