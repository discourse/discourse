# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Filter::Equality do
  subject(:condition) { described_class.new("title") }

  fab!(:kept) { Fabricate(:topic, title: "The rows a filter keeps") }
  fab!(:also_kept) { Fabricate(:topic, title: "More rows it keeps as well") }
  fab!(:dropped) { Fabricate(:topic, title: "The rows it leaves behind") }

  describe "#call" do
    subject(:narrowed) { condition.call(Topic.all, value).map(&:id) }

    let(:value) { kept.title }

    it "keeps the rows whose column holds the value" do
      expect(narrowed).to contain_exactly(kept.id)
    end

    context "with a list of values" do
      let(:value) { [kept.title, also_kept.title] }

      it "keeps the rows holding any of them" do
        expect(narrowed).to contain_exactly(kept.id, also_kept.id)
      end
    end
  end
end
