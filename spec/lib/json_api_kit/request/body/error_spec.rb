# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Body::Error do
  subject(:refusal) { described_class.new(error, document:) }

  let(:document) { { "data" => { "type" => "users", "attributes" => {} } } }
  let(:contract) { JsonApiKit::Request::Body::Contract.new(document, type: "topics") }
  let(:error) { contract.errors.add(attribute, reason, **options) }
  let(:attribute) { :"data.type" }
  let(:reason) { :equal_to }
  let(:options) { { count: "topics" } }

  describe "#status" do
    it "reports an endpoint type conflict" do
      expect(refusal.status).to eq("409")
    end

    context "when a different member fails a comparison" do
      let(:attribute) { :"data.attributes" }

      it "reports invalid input" do
        expect(refusal.status).to eq("400")
      end
    end

    context "when the client supplies an id" do
      let(:attribute) { :"data.id" }
      let(:reason) { :unsupported }
      let(:options) { {} }

      it "reports an unsupported client-generated id" do
        expect(refusal.status).to eq("403")
      end
    end

    context "when a different member is unsupported" do
      let(:attribute) { :"data.attributes" }
      let(:reason) { :unsupported }
      let(:options) { { message: "Unsupported attributes." } }

      it "reports invalid input" do
        expect(refusal.status).to eq("400")
      end
    end
  end

  describe "#detail" do
    it "describes the endpoint type conflict" do
      expect(refusal.detail).to eq("type must be topics for this endpoint.")
    end

    context "when an error has no presentation rule" do
      let(:attribute) { :"data.attributes" }
      let(:reason) { :unsupported }
      let(:options) { { message: "Unsupported attributes." } }

      it "preserves the validation message" do
        expect(refusal.detail).to eq("Unsupported attributes.")
      end
    end
  end
end
