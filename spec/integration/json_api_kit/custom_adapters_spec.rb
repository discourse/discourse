# frozen_string_literal: true

module JsonApiKitAdapterSpec
  class Note < Data.define(:id, :owner_id, :text)
    def self.records = []
  end

  class TestAdapter < JsonApiKit::Adapter
    def all(request, scoped_to: nil)
      JsonApiKit::Query::Result.new(
        resource,
        request,
        records: resource.apply_filters(scoped_to || Note.records, request.filtering),
      )
    end

    def filter(records, name, value) = records.select { it.public_send(name) == value }

    def related_records(_relationship, owners:, owner_resource:)
      RelatedNotes.new(resource, owners)
    end
  end

  class RelatedNotes
    def initialize(resource, owners)
      @resource = resource
      @owners = owners
    end

    def scope = Note.records.select { owners.map(&:id).include?(it.owner_id) }

    def records_by_owner(params)
      owners.to_h do |owner|
        [owner, JsonApiKit::Records.new(records(params).select { it.record.owner_id == owner.id })]
      end
    end

    private

    attr_reader :resource, :owners

    def records(params) = @records ||= resource.all(params, scoped_to: scope).records
  end

  class NoteResource < JsonApiKit::Resource
    adapter TestAdapter
    model Note
    type :notes

    attribute :text
    filter :text
  end

  class TopicResource < JsonApiKit::Resource
    model Topic
    type :topics

    attribute :title
    has_many :notes, resource: NoteResource
  end
end

RSpec.describe "JSON:API with a test adapter for plain Ruby objects" do
  let(:guardian) { Guardian.new }
  let(:edition) { JsonApiKit::Edition.current }
  let(:resource) { JsonApiKitAdapterSpec::NoteResource }
  let(:params) { {} }
  let(:notes) do
    [
      JsonApiKitAdapterSpec::Note.new(id: "first", owner_id: 1, text: "First note"),
      JsonApiKitAdapterSpec::Note.new(id: "second", owner_id: 2, text: "Second note"),
    ]
  end
  let(:client) do
    JsonApiKit::Client.new(
      guardian:,
      edition:,
      urls:
        JsonApiKit::Urls.new(
          base: "https://example.com/api",
          current: "https://example.com/api/#{resource.type}",
        ),
    )
  end

  before { allow(JsonApiKitAdapterSpec::Note).to receive(:records).and_return(notes) }

  describe "a collection" do
    subject(:document) { JsonApiKit::Document::Collection.for(params, resource:, client:).to_h }

    let(:ids) { document.fetch(:data).map { it.fetch(:id) } }

    context "when the request supplies a sparse fieldset" do
      let(:params) { { fields: { notes: "" } } }

      it "renders identifiers without attributes", :aggregate_failures do
        expect(ids).to contain_exactly("first", "second")
        expect(document.fetch(:data)).to all(exclude(:attributes))
      end
    end

    context "when a historical request filters and selects a renamed field" do
      let(:edition) do
        JsonApiKit::Edition.new(
          [
            Class
              .new(JsonApiKit::VersionChange) do
                resource :notes do
                  renamed_attribute from: :body, to: :text
                  renamed_filter from: :body, to: :text
                end
              end
              .new(__FILE__),
          ],
        )
      end
      let(:params) { { fields: { notes: "body" }, filter: { body: "Second note" } } }

      it "renders the requested version of the field" do
        expect(document.fetch(:data)).to contain_exactly(
          a_hash_including(id: "second", attributes: { "body" => "Second note" }),
        )
      end
    end

    context "when the resource inherits its adapter" do
      let(:resource) { Class.new(super()) }

      it "uses the inherited adapter" do
        expect(ids).to contain_exactly("first", "second")
      end
    end
  end

  describe "a relationship between adapters" do
    subject(:document) do
      JsonApiKit::Document::Individual.for(topic.id, { include: "notes" }, resource:, client:).to_h
    end

    fab!(:topic)

    let(:resource) { JsonApiKitAdapterSpec::TopicResource }
    let(:notes) do
      [JsonApiKitAdapterSpec::Note.new(id: "first", owner_id: topic.id, text: "A note")]
    end

    it "includes records without an ActiveRecord association", :aggregate_failures do
      expect(document.dig(:data, :relationships, "notes", :data)).to eq(
        [{ type: "notes", id: "first" }],
      )
      expect(document.fetch(:included)).to contain_exactly(
        a_hash_including(type: "notes", id: "first", attributes: { "text" => "A note" }),
      )
    end
  end
end
