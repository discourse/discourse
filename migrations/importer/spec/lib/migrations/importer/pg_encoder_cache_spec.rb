# frozen_string_literal: true

RSpec.describe Migrations::Importer::PgEncoderCache do
  describe "the JSON encoder" do
    subject(:encoder) { described_class.get_encoder("json") }

    it "encodes hashes, arrays and scalars as JSON" do
      expect(encoder.encode({ "a" => 1 })).to eq('{"a":1}')
      expect(encoder.encode([1, "two", nil])).to eq('[1,"two",null]')
      expect(encoder.encode("plain")).to eq('"plain"')
      expect(encoder.encode(42)).to eq("42")
    end

    it "encodes non-ASCII text without escaping" do
      expect(encoder.encode({ "name" => "Müller" })).to eq('{"name":"Müller"}')
    end
  end

  describe ".get_encoder" do
    it "returns the JSON encoder for json and jsonb" do
      expect(described_class.get_encoder("json")).to be_a(PG::TextEncoder::JSON)
      expect(described_class.get_encoder("jsonb")).to be_a(PG::TextEncoder::JSON)
    end

    it "normalizes PG's internal array type names" do
      expect(described_class.get_encoder("_int4")).to be_a(PG::TextEncoder::Array)
    end

    it "fails fast on unmapped types" do
      expect { described_class.get_encoder("tsvector") }.to raise_error(
        RuntimeError,
        /Unsupported PG type tsvector/,
      )
    end
  end
end
