# frozen_string_literal: true

RSpec.describe JsonApiKit::Query::Individual do
  subject(:reading) { described_class.new(resource, request) }

  fab!(:topic) { Fabricate(:topic, title: "The row an id names") }
  fab!(:other_topic) { Fabricate(:topic, title: "A row nobody named") }

  let(:resource) { resource_class.new(guardian:, edition:) }
  let(:resource_class) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      attribute :title
    end
  end
  let(:request) do
    JsonApiKit::Request::Individual.new(
      JsonApiKit::Request::Input.with_defaults(params, resource:, default_sorts:),
      guardian:,
      edition:,
    )
  end
  let(:edition) { JsonApiKit::Edition.current }
  let(:default_sorts) { edition.default_sorts }
  let(:params) { { id: topic.id } }
  let(:guardian) { Guardian.new }
  let(:title) { JsonApiKit::Name::Field.new(value: "title", type: "topics") }

  describe "#record" do
    it "returns the record with that id" do
      expect(reading.record.record).to eq(topic)
    end

    it "renders it with the fields the resource declares" do
      expect(reading.record.attributes).to eq(title => topic.title)
    end

    context "when nothing is there under that id" do
      let(:params) { { id: -1 } }

      it "raises not found instead of answering with nothing" do
        expect { reading.record }.to raise_error(JsonApiKit::NotFound)
      end
    end

    context "when the scope withholds the row" do
      let(:resource_class) { Class.new(super()) { scope { Topic.where(closed: true) } } }

      it "raises not found instead of answering with nothing" do
        expect { reading.record }.to raise_error(JsonApiKit::NotFound)
      end
    end
  end
end
