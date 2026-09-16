# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Input::Individual do
  subject(:input) { described_class.new(parameters, resource:, edition:) }

  let(:parameters) { {} }
  let(:edition) { JsonApiKit::Edition.current }
  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      attribute :title
      sort :title
      default_sort title: :asc
    end
  end

  describe "#invalid?" do
    it "accepts an individual request without adding a sort parameter" do
      expect(input).not_to be_invalid
    end

    context "when the client supplies collection parameters" do
      let(:parameters) { { sort: "title", page: { size: 1 }, filter: { title: "A topic" } } }

      it { is_expected.to be_invalid }
    end
  end

  describe "#refusals" do
    subject(:sources) { input.refusals.map(&:source) }

    let(:parameters) { { sort: "title", page: { size: 1 }, filter: { title: "A topic" } } }

    before { input.invalid? }

    it "reports each collection parameter" do
      expect(sources).to contain_exactly(
        { parameter: "sort" },
        { parameter: "page" },
        { parameter: "filter" },
      )
    end
  end

  describe "#to_h" do
    subject(:fields) { input.to_h.fetch(:fields) }

    let(:parameters) { { fields: { topics: "title" } } }

    before { input.invalid? }

    it "returns the contract's parameters" do
      expect(fields).to eq("topics" => ["title"])
    end
  end
end
