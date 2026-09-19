# frozen_string_literal: true

RSpec.describe JsonApiKit::Linkage::ToMany do
  subject(:linkage) { described_class.new(page, previous_page:) }

  fab!(:topic)

  let(:guardian) { Guardian.new }
  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
    end
  end
  let(:record) do
    JsonApiKit::Record.new(
      JsonApiKit::Pagination::Row.new(record: topic, segment: nil),
      resource.fields(guardian:),
      type: "topics",
    )
  end
  let(:records) { [record] }
  let(:next_page) { JsonApiKit::Pagination::Cursor.new([2]) }
  let(:previous_page) { JsonApiKit::Pagination::Cursor.new([1]) }
  let(:page) { JsonApiKit::Records::Page.new(JsonApiKit::Records.new(records), next_page) }

  describe "#collapse" do
    it "returns every record it holds" do
      expect(linkage.collapse { it.id }).to eq([topic.id.to_s])
    end

    context "when it holds no record" do
      let(:records) { [] }

      it "returns an empty list" do
        expect(linkage.collapse { it.id }).to eq([])
      end
    end
  end

  describe "#pages" do
    it "returns the cursor at each end as a string" do
      expect(linkage.pages).to eq(before: previous_page.to_s, after: next_page.to_s)
    end

    context "when no page lies either side" do
      let(:next_page) { nil }
      let(:previous_page) { nil }

      it "returns nothing at each end" do
        expect(linkage.pages).to eq(before: nil, after: nil)
      end
    end
  end
end
