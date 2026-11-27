# frozen_string_literal: true

RSpec.describe ActiveSupportTypeExtensions::Boolean do
  subject(:type) { described_class.new(**options) }

  let(:options) { {} }

  it "is the type registered for :boolean" do
    expect(ActiveModel::Type.lookup(:boolean)).to be_a(described_class)
  end

  describe "#cast" do
    it "casts like ActiveModel's boolean", :aggregate_failures do
      expect(type.cast("true")).to eq(true)
      expect(type.cast("0")).to eq(false)
      expect(type.cast("")).to be_nil
      expect(type.cast("invalid")).to eq(true)
    end
  end

  describe "#valid_input?" do
    it "accepts booleans, their common encodings and missing values", :aggregate_failures do
      [nil, "", true, false, 1, 0, "1", "0", "true", "false", "on", "off"].each do |value|
        expect(type.valid_input?(value)).to eq(true), "expected #{value.inspect} to be accepted"
      end
    end

    it "rejects anything else", :aggregate_failures do
      ["invalid", "yes", "t", "TRUE", 2, 1.0, [true], { enabled: true }].each do |value|
        expect(type.valid_input?(value)).to eq(false), "expected #{value.inspect} to be rejected"
      end
    end

    context "when not strict" do
      let(:options) { { strict: false } }

      it "accepts anything" do
        expect(type.valid_input?("invalid")).to eq(true)
      end
    end
  end
end
