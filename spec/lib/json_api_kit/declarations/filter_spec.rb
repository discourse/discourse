# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Filter do
  subject(:filter) { described_class.new(:title) { |scope, value| scope.where(title: value) } }

  fab!(:matching_topic) { Fabricate(:topic, title: "The rows a filter keeps") }
  fab!(:dropped_topic) { Fabricate(:topic, title: "The rows it leaves behind") }

  let(:scope) { Topic.all }
  let(:adapter) do
    Class
      .new(JsonApiKit::Resource) do
        model Topic
        type :topics
      end
      .new(guardian: Guardian.new)
      .adapter
  end

  describe "#name" do
    subject(:name) { filter.name }

    it "returns the name a request filters by" do
      expect(name).to eq("title")
    end
  end

  describe "#apply" do
    subject(:kept_ids) { filter.apply(scope, matching_topic.title, adapter:).map(&:id) }

    it "keeps the rows its declared condition allows" do
      expect(kept_ids).to contain_exactly(matching_topic.id)
    end

    context "when the filter declares no condition of its own" do
      subject(:filter) { described_class.new(:title) }

      it "uses the adapter's equality filter" do
        expect(kept_ids).to contain_exactly(matching_topic.id)
      end
    end
  end
end
