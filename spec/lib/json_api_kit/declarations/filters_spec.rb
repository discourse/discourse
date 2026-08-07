# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Filters do
  subject(:filters) { described_class.new(declared) }

  fab!(:open_topic) { Fabricate(:topic, title: "The rows a filter keeps", closed: false) }
  fab!(:another_open_topic) do
    Fabricate(:topic, title: "More rows it keeps as well", closed: false)
  end
  fab!(:closed_topic) { Fabricate(:topic, title: "The rows it leaves behind", closed: true) }

  let(:filter) { JsonApiKit::Declarations::Filter }
  let(:declared) { [filter.new(:title), filter.new(:closed)] }

  describe "#fetch" do
    subject(:fetched) { filters.fetch("title") }

    it "is the filter a caller names" do
      expect(fetched.name).to eq("title")
    end

    context "with a name the resource declared no filter for" do
      subject(:fetched) { filters.fetch("secrets") }

      it "refuses it, a caller asking for a condition nothing offers" do
        expect { fetched }.to raise_error(described_class::Unsupported, /secrets/)
      end
    end
  end

  describe "#apply" do
    subject(:filtered) { filters.apply(Topic.all, filtering).map(&:id) }

    let(:filtering) { { closed: "false" } }

    it "narrows the scope by the filter named" do
      expect(filtered).to contain_exactly(open_topic.id, another_open_topic.id)
    end

    context "with several filters named" do
      let(:filtering) { { closed: "false", title: open_topic.title } }

      it "keeps only the rows every one of them allows" do
        expect(filtered).to contain_exactly(open_topic.id)
      end
    end

    context "when nothing is named" do
      subject(:filtered) { filters.apply(Topic.all, filtering) }

      let(:filtering) { {} }

      it "leaves the scope as it was" do
        expect(filtered).to eq(Topic.all)
      end
    end

    context "with a filter the resource never declared" do
      let(:filtering) { { secrets: "x" } }

      it "refuses to narrow a listing by a filter nobody offered" do
        expect { filtered }.to raise_error(described_class::Unsupported)
      end
    end
  end
end
