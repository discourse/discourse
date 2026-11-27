# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Body::Linkage do
  subject(:body) { described_class.new(document, relationship:, resource:) }

  let(:resource) { GroupResource.new(guardian: Guardian.new, edition:) }
  let(:edition) { JsonApiKit::Edition.current }
  let(:relationship) do
    JsonApiKit::Declarations::Relationship::ToMany.new(:users, resource: UserResource)
  end
  let(:document) { { "data" => [{ "type" => "users", "id" => "0012" }] } }

  describe "#parameters" do
    subject(:parameters) { body.parameters }

    context "when the client uses the previous type name" do
      let(:rename) do
        Class.new(JsonApiKit::VersionChange) { renamed_type from: :people, to: :users }
      end
      let(:edition) { JsonApiKit::Edition.new([rename.new(__FILE__)]) }
      let(:document) { { "data" => [{ "type" => "people", "id" => "0012" }] } }

      it { is_expected.to eq(user_ids: ["0012"]) }
    end

    context "when the client clears a to-many relationship" do
      let(:document) { { "data" => [] } }

      it { is_expected.to eq(user_ids: []) }
    end

    context "when the client clears a to-one relationship" do
      let(:relationship) do
        JsonApiKit::Declarations::Relationship::ToOne.new(:editor, resource: UserResource)
      end
      let(:document) { { "data" => nil } }

      it { is_expected.to eq(editor_id: nil) }
    end
  end

  describe "#refusals" do
    subject(:refusals) { body.refusals }

    let(:sources) { refusals.map(&:source) }

    context "when data and errors appear together" do
      let(:document) { super().merge("errors" => []) }

      it "points to the incompatible errors member" do
        expect(sources).to contain_exactly(pointer: "/errors")
      end
    end
  end

  describe "#validation_errors" do
    subject(:validation_errors) { body.validation_errors(errors) }

    let(:errors) { Service::ContractBase.new.errors }
    let(:sources) { validation_errors.map(&:source) }

    before { errors.add(:"user_ids[0]", "is invalid") }

    it "points to the ID for an indexed relationship error" do
      expect(sources).to contain_exactly(pointer: "/data/0/id")
    end
  end
end
