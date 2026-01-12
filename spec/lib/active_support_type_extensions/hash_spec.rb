# frozen_string_literal: true

RSpec.describe ActiveSupportTypeExtensions::Hash do
  subject(:type) { described_class.new }

  describe "#cast" do
    subject(:casted_value) { type.cast(value) }

    context "when 'value' is a hash" do
      let(:value) { { key: "value", nested: { data: 123 } } }

      it "returns it as-is" do
        expect(casted_value).to eq(value)
      end
    end

    context "when 'value' is a JSON string" do
      let(:value) { '{"key":"value","nested":{"data":123}}' }

      it "parses it" do
        expect(casted_value).to eq({ "key" => "value", "nested" => { "data" => 123 } })
      end
    end

    context "when 'value' is an empty string" do
      let(:value) { "" }

      it "returns an empty hash" do
        expect(casted_value).to eq({})
      end
    end

    context "when 'value' is nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(casted_value).to be_nil
      end
    end

    context "when 'value' is an invalid JSON string" do
      let(:value) { "{invalid json}" }

      it "returns an empty hash" do
        expect(casted_value).to eq({})
      end
    end

    context "when 'value' responds to to_h" do
      let(:value) { [[:a, 1], [:b, 2]] }

      it "converts it using to_h" do
        expect(casted_value).to eq({ a: 1, b: 2 })
      end
    end

    context "when 'value' is something else" do
      let(:value) { "not a hash" }

      it "returns an empty hash" do
        expect(casted_value).to eq({})
      end
    end
  end
end
