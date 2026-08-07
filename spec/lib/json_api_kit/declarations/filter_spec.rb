# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Filter do
  subject(:filter) { described_class.new(:title) { |scope, value| scope.where(title: value) } }

  fab!(:matching) { Fabricate(:topic, title: "The rows a filter keeps") }
  fab!(:other) { Fabricate(:topic, title: "The rows it leaves behind") }

  describe "#name" do
    subject(:name) { filter.name }

    it "is the name a caller filters by" do
      expect(name).to eq("title")
    end
  end

  describe "#apply" do
    subject(:filtered) { filter.apply(Topic.all, matching.title).map(&:id) }

    it "keeps the rows the condition it was declared with allows" do
      expect(filtered).to contain_exactly(matching.id)
    end

    context "when the filter declares nothing but its name" do
      subject(:filter) { described_class.new(:title) }

      it "keeps the rows whose column holds the value" do
        expect(filtered).to contain_exactly(matching.id)
      end
    end
  end
end
