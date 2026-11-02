# frozen_string_literal: true

RSpec.describe JsonApiKit::Adapters::ActiveRecord do
  subject(:adapter) { resource.adapter }

  fab!(:first_topic) { Fabricate(:topic, title: "First topic from the adapter's scope") }
  fab!(:second_topic) { Fabricate(:topic, title: "Second topic from the adapter's scope") }
  fab!(:third_topic) { Fabricate(:topic, title: "Third topic from the adapter's scope") }

  let(:resource) do
    Class
      .new(JsonApiKit::Resource) do
        model Topic
        type :topics
        attribute :title
        filter :title
      end
      .new(guardian:)
  end
  let(:guardian) { Guardian.new }
  let(:available_records) { [first_topic, second_topic, third_topic] }
  let(:scope) { Topic.all }
  let(:restricted_scope) { Topic.where(id: record.id) }
  let(:empty_scope) { Topic.none }
  let(:filter_name) { "title" }
  let(:missing_id) { (Topic.maximum(:id) + 1).to_s }
  let(:params) { {} }
  let(:request) do
    JsonApiKit::Request::Collection.new(params, guardian:, edition: JsonApiKit::Edition.current)
  end

  describe "#filter" do
    subject(:matching_records) { adapter.filter(scope, filter_name, value).to_a }

    let(:value) { first_topic.title }

    it "restricts the scope to matching records" do
      expect(matching_records).to contain_exactly(first_topic)
    end

    context "when the value is an array" do
      let(:value) { [first_topic.title, second_topic.title] }

      it "keeps the rows whose column holds one of them" do
        expect(matching_records).to contain_exactly(first_topic, second_topic)
      end
    end
  end

  describe "#requested_page" do
    subject(:page) { adapter.requested_page(request) }

    before { allow(described_class::Page::Requested).to receive(:from).and_call_original }

    it "builds the requested page for this adapter" do
      page

      expect(described_class::Page::Requested).to have_received(:from).with(request, adapter:)
    end
  end

  describe "#collection?" do
    it "recognizes an ActiveRecord relation" do
      expect(adapter).to be_a_collection(scope)
    end
  end

  it_behaves_like "a resource adapter"
end
