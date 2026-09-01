# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Filter::Equality do
  subject(:condition) { described_class.new("title") }

  fab!(:kept_topic) { Fabricate(:topic, title: "The rows a filter keeps") }
  fab!(:also_kept) { Fabricate(:topic, title: "More rows it keeps as well") }
  fab!(:dropped_topic) { Fabricate(:topic, title: "The rows it leaves behind") }

  describe "#call" do
    subject(:kept_ids) { condition.call(Topic.all, value).map(&:id) }

    let(:value) { kept_topic.title }

    it "keeps the rows whose column holds the value" do
      expect(kept_ids).to contain_exactly(kept_topic.id)
    end

    context "when the value is an array" do
      let(:value) { [kept_topic.title, also_kept.title] }

      it "keeps the rows whose column holds one of them" do
        expect(kept_ids).to contain_exactly(kept_topic.id, also_kept.id)
      end
    end
  end
end
