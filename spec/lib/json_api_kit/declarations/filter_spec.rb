# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Filter do
  subject(:filter) { described_class.new(:title) { |scope, value| scope.where(title: value) } }

  fab!(:matching_topic) { Fabricate(:topic, title: "The rows a filter keeps") }
  fab!(:dropped_topic) { Fabricate(:topic, title: "The rows it leaves behind") }

  let(:scope) { Topic.all }

  describe "#name" do
    subject(:name) { filter.name }

    it "returns the name a request filters by" do
      expect(name).to eq("title")
    end
  end

  describe "#apply" do
    subject(:kept_ids) { filter.apply(scope, matching_topic.title).map(&:id) }

    it "keeps the rows its declared condition allows" do
      expect(kept_ids).to contain_exactly(matching_topic.id)
    end

    context "when the filter declares no condition of its own" do
      subject(:filter) { described_class.new(:title) }

      let(:equality) { instance_spy(described_class::Equality) }

      before do
        allow(described_class::Equality).to receive(:new).with("title").and_return(equality)
      end

      it "compares the column of its own name to the value" do
        filter.apply(scope, matching_topic.title)

        expect(equality).to have_received(:call).with(scope, matching_topic.title)
      end
    end
  end
end
