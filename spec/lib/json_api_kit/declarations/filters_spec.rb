# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Filters do
  subject(:filters) { described_class.new(declarations) }

  fab!(:open_topic) { Fabricate(:topic, title: "The rows a filter keeps", closed: false) }
  fab!(:another_open_topic) do
    Fabricate(:topic, title: "More rows it keeps as well", closed: false)
  end
  fab!(:closed_topic) { Fabricate(:topic, title: "The rows it leaves behind", closed: true) }

  let(:filter_class) { JsonApiKit::Declarations::Filter }
  let(:declarations) { [filter_class.new(:title), filter_class.new(:closed)] }
  let(:scope) { Topic.all }

  describe "#fetch" do
    subject(:filter) { filters.fetch("title") }

    it "returns that filter" do
      expect(filter.name).to eq("title")
    end

    context "when the resource declares no filter by that name" do
      subject(:filter) { filters.fetch("secrets") }

      it "refuses the request" do
        expect { filter }.to raise_error(KeyError)
      end
    end
  end

  describe "#apply" do
    subject(:kept_ids) { filters.apply(scope, filtering).map(&:id) }

    let(:filtering) { { "closed" => "false" } }

    it "narrows the scope by that filter" do
      expect(kept_ids).to contain_exactly(open_topic.id, another_open_topic.id)
    end

    context "when the filtering holds two filters" do
      let(:filtering) { { "closed" => "false", "title" => open_topic.title } }

      it "keeps only the rows every one of them allows" do
        expect(kept_ids).to contain_exactly(open_topic.id)
      end
    end

    context "when there is no filtering" do
      it "returns the same scope" do
        expect(filters.apply(scope)).to be(scope)
      end
    end

    context "when the resource declares no filter by that name" do
      let(:filtering) { { secrets: "x" } }

      it "refuses the request" do
        expect { kept_ids }.to raise_error(KeyError)
      end
    end
  end
end
