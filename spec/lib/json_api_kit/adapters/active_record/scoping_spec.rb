# frozen_string_literal: true

RSpec.describe JsonApiKit::Adapters::ActiveRecord::Scoping do
  subject(:scoping) { described_class.for(scoped_to) }

  fab!(:topic)
  fab!(:another, :topic)

  let(:scoped_to) { Topic.where(id: topic.id) }
  let(:requested) { JsonApiKit::Adapters::ActiveRecord::Page::Requested.for }

  describe "#apply" do
    it "keeps a listing to those rows" do
      expect(scoping.apply(Topic.all).map(&:id)).to eq([topic.id])
    end

    context "when a caller keeps it to nothing" do
      let(:scoped_to) { nil }

      it "leaves the listing whole" do
        expect(scoping.apply(Topic.all).map(&:id)).to contain_exactly(topic.id, another.id)
      end
    end
  end

  describe "#page" do
    it "returns that page" do
      expect(scoping.page(requested)).to be(requested)
    end

    context "when a sideload keeps it to the rows a relationship reaches" do
      let(:scoped_to) do
        JsonApiKit::Adapters::ActiveRecord::Schema.new(Topic).association(:posts, [topic])
      end

      it "reads one page for each owner instead" do
        expect(scoping.page(requested)).to be_a(JsonApiKit::Adapters::ActiveRecord::Page::PerOwner)
      end
    end
  end
end
