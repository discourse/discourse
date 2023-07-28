# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Types::Array do
  subject(:type) { described_class.new }

  describe "#cast" do
    subject(:casted_value) { type.cast(value) }

    context "when 'value' is a string" do
      let(:value) { "first,second,third" }

      it "splits it" do
        expect(casted_value).to eq(%w[first second third])
      end
    end

    context "when 'value' is an array" do
      let(:value) { %w[existing array] }

      it "returns it" do
        expect(casted_value).to eq(value)
      end
    end

    context "when 'value' is something else" do
      let(:value) { Time.current }

      it "wraps it in a new array" do
        expect(casted_value).to eq([value])
      end
    end
  end
end
