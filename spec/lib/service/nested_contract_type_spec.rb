# frozen_string_literal: true

RSpec.describe Service::NestedContractType do
  subject(:type) { described_class.new(contract_class:, nested_type:) }

  let(:contract_class) do
    Class.new(Service::ContractBase) do
      attribute :id, :integer
      attribute :name, :symbol
    end
  end

  describe "#cast" do
    subject(:casted_value) { type.cast(value) }

    context "when 'nested_type' is :hash" do
      let(:nested_type) { :hash }

      context "when 'value' is a hash" do
        let(:value) { { id: "1", name: "symbol" } }

        it "converts the hash to a contract" do
          expect(casted_value).to be_a(contract_class)
          expect(casted_value).to have_attributes(id: 1, name: :symbol)
        end
      end

      context "when 'value' is an array" do
        let(:value) { [{ id: "1", name: "symbol" }] }

        it "returns nothing" do
          expect(casted_value).to be_nil
        end
      end

      context "when 'value' is something else" do
        let(:value) { "value" }

        it "returns nothing" do
          expect(casted_value).to be_nil
        end
      end
    end

    context "when 'nested_type' is :array" do
      let(:nested_type) { :array }

      context "when 'value' is a hash" do
        let(:value) { { id: "1", name: "symbol" } }

        it "returns nothing" do
          expect(casted_value).to be_nil
        end
      end

      context "when 'value' is an array" do
        let(:value) { [{ id: "1", name: "symbol" }, { id: "2", name: "other_symbol" }, ""] }

        it "converts the hashes from the array to an array of contracts" do
          expect(casted_value).to contain_exactly(
            an_object_having_attributes(id: 1, name: :symbol),
            an_object_having_attributes(id: 2, name: :other_symbol),
          )
        end
      end

      context "when 'value' is something else" do
        let(:value) { "value" }

        it "returns nothing" do
          expect(casted_value).to be_nil
        end
      end
    end
  end
end
