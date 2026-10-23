# frozen_string_literal: true

module JsonApiKitAdapterSpec
  class Note < Data.define(:id, :owner_id, :text)
    def self.records = []
  end

  class NotesAdapter < JsonApiKit::Adapter
    def all(request, scoped_to: nil)
      JsonApiKit::Query::Result.new(
        resource,
        request,
        records: resource.apply_filters(scoped_to || Note.records, request.filtering),
      )
    end

    def find(request)
      JsonApiKit::Query::Result.new(resource, request, records: [record_for(request.id)])
    end

    def record_for(id)
      Note.records.detect { it.id == id.to_s } or raise JsonApiKit::NotFound
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
    adapter NotesAdapter
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

  class ContextAdapter < JsonApiKit::Adapters::ActiveRecord
    def initialize(resource)
      super
      @owner_id = resource.guardian.user.id
    end

    def scope_for(guardian) = super.where(user_id: @owner_id)
  end

  class ContextTopicResource < JsonApiKit::Resource
    adapter ContextAdapter
    model Topic
    type :topics

    attribute :title
    sort :title
    anchor :title
    anchor(:mine) { |topics, guardian| topics.where(user_id: guardian.user.id) }
  end

  class AlphabeticalAdapter < ContextAdapter
    class Definition < JsonApiKit::Adapters::ActiveRecord::Definition
      def order(ordering) = super(ordering.presence || { "title" => :asc })
    end
  end
end

RSpec.describe "JSON:API resource adapters" do
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
          current: "https://example.com/api/notes",
        ),
    )
  end

  before { allow(JsonApiKitAdapterSpec::Note).to receive(:records).and_return(notes) }

  describe "a collection" do
    subject(:document) { JsonApiKit::Document::Collection.for(params, resource:, client:).to_h }

    it "renders records from the custom adapter" do
      expect(document.fetch(:data)).to contain_exactly(
        a_hash_including(id: "first", attributes: { "text" => "First note" }),
        a_hash_including(id: "second", attributes: { "text" => "Second note" }),
      )
    end

    context "when the request supplies a filter" do
      let(:params) { { filter: { text: "Second note" } } }

      it "applies the adapter's filter" do
        expect(document.fetch(:data)).to contain_exactly(a_hash_including(id: "second"))
      end
    end

    context "when the request supplies a sparse fieldset" do
      let(:params) { { fields: { notes: "" } } }

      it "omits the unrequested attributes" do
        expect(document.fetch(:data)).to all(exclude(:attributes))
      end
    end

    context "when the requested version uses an earlier attribute name" do
      let(:edition) do
        JsonApiKit::Edition.new(
          [
            Class
              .new(JsonApiKit::VersionChange) do
                resource(:notes) { renamed_attribute from: :body, to: :text }
              end
              .new(__FILE__),
          ],
        )
      end
      let(:params) { { fields: { notes: "body" } } }

      it "renders the requested version of the field" do
        expect(document.dig(:data, 0, :attributes)).to eq("body" => "First note")
      end
    end

    context "when the resource inherits its adapter" do
      let(:resource) { Class.new(super()) }

      it "uses the inherited adapter" do
        expect(document.fetch(:data).size).to eq(2)
      end
    end

    context "when the adapter does not accept a cursor" do
      let(:params) { { page: { after: "unsupported" } } }

      it "returns an invalid parameter error" do
        expect(document.fetch(:errors)).to include(
          a_hash_including(status: "400", source: { parameter: "page[after]" }),
        )
      end
    end

    context "when the request supplies an undeclared anchor" do
      let(:params) { { page: { anchor: { text: "First note" } } } }

      it "returns an invalid parameter error" do
        expect(document.fetch(:errors)).to include(a_hash_including(status: "400"))
      end
    end
  end

  describe "an individual resource" do
    subject(:document) { JsonApiKit::Document::Individual.for(id, params, resource:, client:) }

    let(:id) { "second" }

    it "finds the record through the adapter" do
      expect(document.to_h.fetch(:data)).to include(id:, attributes: { "text" => "Second note" })
    end

    context "when the record does not exist" do
      let(:id) { "missing" }

      it "returns a missing resource error" do
        expect(document.status).to eq("404")
      end
    end

    context "when the resource explicitly selects the ActiveRecord adapter" do
      fab!(:topic)

      let(:id) { topic.id.to_s }
      let(:resource) do
        Class.new(JsonApiKit::Resource) do
          adapter :active_record
          model Topic
          type :topics
          attribute :title
        end
      end

      it "renders the database record" do
        expect(document.to_h.fetch(:data)).to include(id:, attributes: { "title" => topic.title })
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

  describe "inherited ActiveRecord declarations" do
    subject(:ids) do
      JsonApiKit::Document::Collection
        .for({}, resource:, client:)
        .to_h
        .fetch(:data)
        .map { it.fetch(:id) }
    end

    fab!(:first_topic) { Fabricate(:topic, title: "Zulu adapter topic") }
    fab!(:second_topic) { Fabricate(:topic, title: "Alpha adapter topic") }

    let(:parent_resource) do
      Class.new(JsonApiKit::Resource) do
        model Topic
        type :topics
        unique_by :title, :id
      end
    end

    context "when a subclass clears the inherited scope" do
      let(:parent_resource) { Class.new(super()) { scope { Topic.none } } }
      let(:resource) { Class.new(parent_resource) { scope } }

      it "reads the records through the default scope" do
        expect(ids).to contain_exactly(first_topic.id.to_s, second_topic.id.to_s)
      end
    end

    context "when a subclass clears the inherited unique key" do
      let(:resource) { Class.new(parent_resource) { unique_by } }

      it "orders records by the model's primary key" do
        expect(ids).to eq([first_topic.id.to_s, second_topic.id.to_s])
      end
    end
  end

  describe "an adapter that uses request context" do
    fab!(:author, :user)
    fab!(:oldest) do
      Fabricate(:topic, user: author, title: "Zulu context topic", created_at: Time.utc(2026, 8, 1))
    end
    fab!(:newest) do
      Fabricate(
        :topic,
        user: author,
        title: "Alpha context topic",
        created_at: Time.utc(2026, 8, 2),
      )
    end
    fab!(:other_topic, :topic)

    let(:guardian) { author.guardian }
    let(:resource) { JsonApiKitAdapterSpec::ContextTopicResource }
    let(:ordering) { { "title" => :asc } }
    let(:cursor) { resource.order(ordering).locate(Topic.where(id: oldest.id)).cursor }
    let(:anchoring) { JsonApiKit::Anchoring.for(:mine) }
    let(:anchored_topic) do
      resource
        .anchors(guardian)
        .locate(anchoring, scope: Topic.all, order: resource.order({}))
        .record
    end

    it "reads the class schema without request context" do
      expect(resource.schema.primary_key).to eq(:id)
    end

    it "builds the class ordering without request context" do
      expect(resource.order(ordering).leading.name).to eq(:title)
    end

    it "checks the class cursor against its ordering" do
      expect(resource).to be_paged_from(cursor, ordering:)
    end

    it "checks the class anchor against its ordering" do
      expect(resource).to be_anchored_by(anchor_name: :title, ordering:)
    end

    it "supplies the guardian to the class scope lookup" do
      expect(resource.scope_for(guardian)).to contain_exactly(oldest, newest)
    end

    it "supplies the guardian to computed anchors" do
      expect(anchored_topic).to eq(oldest)
    end

    it "uses the same context for a collection lookup" do
      expect(resource.all(guardian:).records.map(&:record)).to contain_exactly(oldest, newest)
    end

    context "when the adapter specializes its definition" do
      let(:resource) { Class.new(super()) { adapter JsonApiKitAdapterSpec::AlphabeticalAdapter } }

      it "uses the specialization for class operations" do
        expect(resource.order({}).leading.name).to eq(:title)
      end

      it "uses the specialization for request operations" do
        expect(resource.all(guardian:).records.map(&:record)).to eq([newest, oldest])
      end
    end

    context "when the requested version retains a removed sort" do
      let(:edition) do
        JsonApiKit::Edition.new(
          [
            Class
              .new(JsonApiKit::VersionChange) { resource(:topics) { removed_sort :created_at } }
              .new(__FILE__),
          ],
        )
      end
      let(:params) { { sort: "createdAt" } }
      let(:document) { JsonApiKit::Document::Collection.for(params, resource:, client:) }
      let(:ids) { document.to_h.fetch(:data).map { it.fetch(:id) } }

      before { resource.order(ordering) }

      it "uses the instance's effective declarations" do
        expect(ids).to eq([oldest.id.to_s, newest.id.to_s])
      end

      context "when a current request follows the historical request" do
        let(:current_client) do
          JsonApiKit::Client.new(guardian:, edition: JsonApiKit::Edition.current, urls: client.urls)
        end
        let(:current_document) do
          JsonApiKit::Document::Collection.for(params, resource:, client: current_client)
        end

        before { document.to_h }

        it "keeps the current edition's declarations independent" do
          expect(current_document.status).to eq("400")
        end
      end
    end
  end
end
