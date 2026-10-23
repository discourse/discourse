# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Filters do
  subject(:filters) { described_class.new(declarations) }

  let(:filter_class) { JsonApiKit::Declarations::Filter }
  let(:declarations) { [filter_class.new(:title), filter_class.new(:closed)] }

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

  describe "#with" do
    subject(:combined) { filters.with([filter_class.new(:archived)]) }

    it "includes the additional declaration" do
      expect(combined.names).to contain_exactly("title", "closed", "archived")
    end

    it "preserves the original collection" do
      expect { combined.names }.not_to change(filters, :names)
    end
  end

  describe "#apply" do
    subject(:matching_topics) { filters.apply(scope, filtering, adapter:) }

    let(:open_topic) { { title: "First topic", closed: false } }
    let(:another_open_topic) { { title: "Second topic", closed: false } }
    let(:closed_topic) { { title: "Closed topic", closed: true } }
    let(:scope) { [open_topic, another_open_topic, closed_topic] }
    let(:open_topics) { [open_topic, another_open_topic] }
    let(:adapter) { instance_double(JsonApiKit::Adapters::ActiveRecord) }
    let(:filtering) { { "closed" => false } }

    before do
      allow(adapter).to receive(:filter).with(scope, "closed", false).and_return(open_topics)
    end

    it "narrows the scope by that filter" do
      expect(matching_topics).to contain_exactly(open_topic, another_open_topic)
    end

    context "when the filtering holds two filters" do
      let(:filtering) { super().merge("title" => open_topic.fetch(:title)) }

      before do
        allow(adapter).to receive(:filter).with(
          open_topics,
          "title",
          open_topic.fetch(:title),
        ).and_return([open_topic])
      end

      it "keeps only the rows every one of them allows" do
        expect(matching_topics).to contain_exactly(open_topic)
      end
    end

    context "when there is no filtering" do
      let(:filtering) { {} }

      it "returns the same scope" do
        expect(matching_topics).to be(scope)
      end

      context "when declarations are evaluated lazily" do
        let(:declarations) { Enumerator.new { raise "Filters were evaluated." } }

        it "returns the scope without evaluating the declarations" do
          expect(matching_topics).to be(scope)
        end
      end
    end

    context "when the resource declares no filter by that name" do
      let(:filtering) { { secrets: "x" } }

      it "refuses the request" do
        expect { matching_topics }.to raise_error(KeyError)
      end
    end
  end
end
