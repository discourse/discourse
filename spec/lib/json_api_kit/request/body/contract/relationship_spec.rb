# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Body::Contract::Relationship do
  subject(:contract) { contract_class.new(location:, type: "users") }

  let(:contract_class) { described_class::ToMany }
  let(:location) { JsonApiKit::Request::Body::Location.new(document, %w[data relationships users]) }
  let(:document) { { "data" => { "relationships" => { "users" => relationship } } } }
  let(:relationship) { { "data" => [identifier] } }
  let(:identifier) { { "type" => "users", "id" => 12 } }
  let(:pointer) { "/data/relationships/users/data/0/id" }
  let(:refusal_sources) { contract.refusals.map(&:source) }

  describe "#valid?" do
    it "includes identifier errors in its validity result", :aggregate_failures do
      expect(contract).not_to be_valid
      expect(contract.errors.size).to eq(1)
      expect(refusal_sources).to contain_exactly(pointer:)
    end

    context "when an identifier has the wrong type" do
      let(:identifier) { super().merge("type" => "groups", "id" => "12") }
      let(:pointer) { "/data/relationships/users/data/0/type" }

      it "preserves the nested error status and location", :aggregate_failures do
        expect(contract).to be_invalid
        expect(contract.errors).not_to be_empty
        expect(contract.refusals).to contain_exactly(
          have_attributes(
            status: "409",
            detail: "type must be users for this relationship.",
            source: {
              pointer:,
            },
          ),
        )
      end
    end

    context "when the relationship structure is invalid" do
      let(:relationship) { { "data" => false } }
      let(:pointer) { "/data/relationships/users/data" }

      it "rejects invalid linkage structure", :aggregate_failures do
        expect(contract).to be_invalid
        expect(refusal_sources).to contain_exactly(pointer:)
      end
    end

    context "when the collection is empty" do
      let(:relationship) { { "data" => [] } }

      it "accepts the clearing value", :aggregate_failures do
        expect(contract).to be_valid
        expect(contract.errors).to be_empty
        expect(contract.refusals).to be_empty
      end
    end

    context "when the relationship is to-one" do
      let(:contract_class) { described_class::ToOne }
      let(:relationship) { { "data" => identifier } }
      let(:pointer) { "/data/relationships/users/data/id" }

      it "includes the identifier errors", :aggregate_failures do
        expect(contract).to be_invalid
        expect(contract.errors).not_to be_empty
        expect(refusal_sources).to contain_exactly(pointer:)
      end

      context "when the linkage is null" do
        let(:relationship) { { "data" => nil } }

        it "accepts the clearing value", :aggregate_failures do
          expect(contract).to be_valid
          expect(contract.errors).to be_empty
          expect(contract.refusals).to be_empty
        end
      end
    end
  end
end
