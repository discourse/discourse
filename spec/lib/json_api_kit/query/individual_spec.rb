# frozen_string_literal: true

RSpec.describe JsonApiKit::Query::Individual do
  subject(:reading) { described_class.new(resource, request) }

  fab!(:topic) { Fabricate(:topic, title: "The row an id names") }
  fab!(:other_topic) { Fabricate(:topic, title: "A row nobody named") }

  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      attribute :title
    end
  end
  let(:request) { JsonApiKit::Request::Individual.new(params, guardian:) }
  let(:params) { { id: topic.id } }
  let(:guardian) { Guardian.new }

  describe "#record" do
    it "returns the record with that id" do
      expect(reading.record.record).to eq(topic)
    end

    it "renders it with the fields the resource declares" do
      expect(reading.record.attributes).to eq("title" => topic.title)
    end

    context "when nothing is there under that id" do
      let(:params) { { id: -1 } }

      it "refuses the request instead of answering with nothing" do
        expect { reading.record }.to raise_error(JsonApiKit::NotFound)
      end
    end

    context "when the scope withholds the row" do
      let(:resource) { Class.new(super()) { scope { Topic.where(closed: true) } } }

      it "refuses the request instead of answering with nothing" do
        expect { reading.record }.to raise_error(JsonApiKit::NotFound)
      end
    end
  end
end
