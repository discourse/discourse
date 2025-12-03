# frozen_string_literal: true

RSpec.describe ActiveSupportTypeExtensions::Symbol do
  subject(:type) { described_class.new }

  describe "#cast" do
    subject(:casted_value) { type.cast(value) }

    context "when 'value' is a string" do
      let(:value) { "a_symbol" }

      it "converts it" do
        expect(casted_value).to eq(:a_symbol)
      end
    end

    context "when 'value' is a symbol" do
      let(:value) { :a_symbol }

      it "returns it" do
        expect(casted_value).to eq(value)
      end
    end

    context "when 'value' is nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(casted_value).to eq(value)
      end
    end

    context "when 'value' is blank" do
      let(:value) { "" }

      it "returns nil" do
        expect(casted_value).to be_nil
      end
    end

    context "when 'value' is something else" do
      let(:value) { 123 }

      it "converts it" do
        expect(casted_value).to eq(:"123")
      end
    end
  end
end
