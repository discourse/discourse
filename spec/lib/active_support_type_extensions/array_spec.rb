# frozen_string_literal: true

RSpec.describe ActiveSupportTypeExtensions::Array do
  subject(:type) { described_class.new(compact_blank:) }

  let(:compact_blank) { false }

  describe "#cast" do
    subject(:casted_value) { type.cast(value) }

    context "when an element type is supplied" do
      let(:type) { described_class.new(element_type: ActiveModel::Type::String.new) }
      let(:value) { ["0012", 34] }

      it "casts each element using that type" do
        expect(casted_value).to eq(%w[0012 34])
      end

      context "when the input is a delimited string" do
        let(:value) { "0012,0034" }

        it "preserves string identifiers" do
          expect(casted_value).to eq(%w[0012 0034])
        end
      end

      context "when the input is a scalar" do
        let(:value) { 12 }

        it "casts the wrapped value" do
          expect(casted_value).to eq(["12"])
        end

        context "when the scalar cannot be cast" do
          let(:type) { described_class.new(element_type: ActiveModel::Type::Integer.new) }
          let(:value) { {} }

          it "retains the invalid element" do
            expect(casted_value).to eq([nil])
          end
        end
      end

      context "when the input is nil" do
        let(:value) { nil }

        it { is_expected.to be_nil }
      end

      context "when the input is an empty array" do
        let(:value) { [] }

        it { is_expected.to be_empty }
      end
    end

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

    context "when 'value' is an array containing falsy or empty values" do
      let(:value) { [nil, "", false, []] }

      context "when the `compact_blank` option is false" do
        it "returns the original array" do
          expect(casted_value).to eq(value)
        end
      end

      context "when the `compact_blank` option is true" do
        let(:compact_blank) { true }

        it "cleans the array" do
          expect(casted_value).to eq([])
        end
      end
    end
  end
end
