# frozen_string_literal: true

module JsonApiKitAdapterSpec
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

RSpec.describe "JSON:API ActiveRecord adapter integration" do
  let(:guardian) { Guardian.new }
  let(:edition) { JsonApiKit::Edition.current }
  let(:params) { {} }
  let(:urls) do
    JsonApiKit::Urls.new(base: "https://example.com/api", current: "https://example.com/api/topics")
  end
  let(:client) { JsonApiKit::Client.new(guardian:, edition:, urls:) }

  describe "an explicit ActiveRecord adapter" do
    subject(:document) { JsonApiKit::Document::Individual.for(id, params, resource:, client:) }

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
    let(:records) { resource.all(guardian:).records.map(&:record) }
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
      expect(records).to contain_exactly(oldest, newest)
    end

    context "when the adapter specializes its definition" do
      let(:resource) { Class.new(super()) { adapter JsonApiKitAdapterSpec::AlphabeticalAdapter } }

      it "uses the specialization for class operations" do
        expect(resource.order({}).leading.name).to eq(:title)
      end

      it "uses the specialization for request operations" do
        expect(records).to eq([newest, oldest])
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
