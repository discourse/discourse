# frozen_string_literal: true

RSpec.describe ActiveSupportTypeExtensions::Array do
  subject(:type) { described_class.new }

  describe "#cast" do
    subject(:casted_value) { type.cast(value) }

    context "when 'value' is a string" do
      let(:value) { "first,second,third" }

      it "splits it" do
        expect(casted_value).to eq(%w[first second third])
      end
    end

    context "when 'value' is a string of numbers" do
      let(:value) { "1,2,3" }

      it "splits it with strings casted as integers" do
        expect(casted_value).to eq([1, 2, 3])
      end
    end

    context "when 'value' is a string of numbers separated by '|'" do
      let(:value) { "1|2|3" }

      it "splits it with strings casted as integers" do
        expect(casted_value).to eq([1, 2, 3])
      end
    end

    context "when 'value' has mixed separators" do
      let(:value) { "1,2,3|4" }

      it "splits only on one of the separators" do
        expect(casted_value).to eq(["1,2,3", 4])
      end
    end

    context "when 'value' is an array" do
      let(:value) { %w[existing array] }

      it "returns it" do
        expect(casted_value).to eq(value)
      end
    end

    context "when 'value' is an array of numbers as string" do
      let(:value) { %w[1 2] }

      it "returns it with string casted as integer" do
        expect(casted_value).to eq([1, 2])
      end
    end

    context "when 'value' is an array of numbers" do
      let(:value) { [1, 2] }

      it "returns it" do
        expect(casted_value).to eq([1, 2])
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
