# frozen_string_literal: true

RSpec.shared_examples "a resource adapter" do
  let(:record) { available_records.last }
  let(:id) { record.id.to_s }
  let(:parameters) { { sort: {} } }
  let(:collection_request) do
    JsonApiKit::Request::Collection.new(
      parameters,
      guardian: resource.guardian,
      edition: resource.edition,
    )
  end
  let(:individual_request) do
    JsonApiKit::Request::Individual.new(
      parameters.merge(id:),
      guardian: resource.guardian,
      edition: resource.edition,
    )
  end
  let(:filter_value) { record.public_send(filter_name) }

  describe "#all" do
    subject(:loaded_records) { adapter.all(collection_request, scoped_to:).records.map(&:record) }

    let(:scoped_to) { nil }

    it "returns the available records" do
      expect(loaded_records).to contain_exactly(*available_records)
    end

    context "when the collection is restricted" do
      let(:scoped_to) { restricted_scope }

      it "returns only the records in that scope" do
        expect(loaded_records).to contain_exactly(record)
      end
    end

    context "when the collection is empty" do
      let(:scoped_to) { empty_scope }

      it "returns no records" do
        expect(loaded_records).to be_empty
      end
    end

    context "when the resource scope excludes some requested records" do
      let(:scoped_to) { scope }

      before { resource.class.scope { restricted_scope } }

      it "returns only the records in the resource scope" do
        expect(loaded_records).to contain_exactly(record)
      end
    end

    context "when the request supplies a filter" do
      let(:parameters) { super().merge(filter: { filter_name => filter_value }) }

      it "returns only the matching records" do
        expect(loaded_records).to contain_exactly(record)
      end
    end
  end

  describe "#find" do
    subject(:query) { adapter.find(individual_request) }

    it "returns the identified record" do
      expect(query.record).to have_attributes(id:, type: resource.type, record:)
    end

    context "when the record does not exist" do
      let(:id) { missing_id }

      it "raises a missing record error" do
        expect { query.record }.to raise_error(JsonApiKit::NotFound)
      end
    end
  end

  describe "#record_for" do
    subject(:found_record) { adapter.record_for(id) }

    it "returns the underlying record" do
      expect(found_record).to eq(record)
    end

    context "when the record does not exist" do
      let(:id) { missing_id }

      it "raises a missing record error" do
        expect { found_record }.to raise_error(JsonApiKit::NotFound)
      end
    end
  end

  describe "#collection?" do
    it "recognizes a collection of supplied records" do
      expect(adapter).to be_a_collection(available_records)
    end

    it "distinguishes an individual record" do
      expect(adapter).not_to be_a_collection(record)
    end
  end
end
