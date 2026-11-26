# frozen_string_literal: true

RSpec.describe JsonApiKit::Document::Relationship do
  fab!(:user)

  let(:resource) { UserResource.new(guardian: Guardian.new) }
  let(:input) { JsonApiKit::Request::Input::Empty.new({}, resource:, edition: resource.edition) }
  let(:urls) { JsonApiKit::Urls.new(base: "/api", current: "/api/groups/1/relationships/users") }
  let(:client) do
    JsonApiKit::Client.new(guardian: resource.guardian, edition: resource.edition, urls:)
  end

  describe ".from" do
    subject(:document) { described_class.from(Set[user], resource:, input:, client:) }

    it "renders identifiers from an enumerable" do
      expect(document.to_h.fetch(:data)).to eq([{ type: "users", id: user.id.to_s }])
    end
  end

  describe described_class::ToOne do
    describe ".from" do
      subject(:document) { described_class.from(record, resource:, input:, client:) }

      let(:record) { user }

      it "renders one identifier" do
        expect(document.to_h.fetch(:data)).to eq(type: "users", id: user.id.to_s)
      end

      context "when the relationship is empty" do
        let(:record) { nil }

        it "renders null linkage" do
          expect(document.to_h.fetch(:data)).to be_nil
        end
      end
    end
  end
end
