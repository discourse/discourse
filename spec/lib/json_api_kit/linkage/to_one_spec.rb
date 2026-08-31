# frozen_string_literal: true

RSpec.describe JsonApiKit::Linkage::ToOne do
  subject(:linkage) { described_class.new(records) }

  fab!(:topic)

  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
    end
  end
  let(:record) do
    JsonApiKit::Record.new(
      JsonApiKit::Pagination::Row.new(record: topic, segment: nil),
      resource.fields,
      type: "topics",
    )
  end
  let(:records) { [record] }

  describe "#collapse" do
    it "returns what the block makes of its one record" do
      expect(linkage.collapse { it.id }).to eq(topic.id.to_s)
    end

    context "when it holds no record" do
      let(:records) { [] }

      it "returns nothing" do
        expect(linkage.collapse { it.id }).to be_nil
      end
    end
  end

  describe "#pages" do
    it "returns no page" do
      expect(linkage.pages).to be_empty
    end
  end
end
