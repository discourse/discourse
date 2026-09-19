# frozen_string_literal: true

require_relative "support"

module JsonApiKitSpec
  class DefaultSortPostResource < JsonApiKit::Resource
    model Post
    type :posts

    attribute :post_number
    sort :post_number
    default_sort post_number: :asc
  end

  class DefaultSortTopicResource < JsonApiKit::Resource
    model Topic
    type :topics

    attribute :title
    attribute :created_at
    sort :created_at
    sort :title
    default_sort title: :asc
    anchor :created_at
    anchor :title
    page default: 10, max: 20

    has_many :posts, resource: DefaultSortPostResource
    includes "posts"
  end

  class DefaultSortTopicsController < JsonApiKit::BaseController
    resource DefaultSortTopicResource
  end

  class ChangeTopicDefaultSort < JsonApiKit::VersionChange
    version "2026-09-01"
    description "Topics use their title as the default sort."

    resource :topics do
      changed_default_sort from: { created_at: :desc }
    end

    resource :posts do
      changed_default_sort from: { post_number: :desc }
    end
  end
end

RSpec.describe "JSON:API default sorts", type: :request do
  include_context "with a listing of topics"

  let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
  let(:changes) { [JsonApiKitSpec::ChangeTopicDefaultSort.new(__FILE__)] }
  let(:version_changes) { JsonApiKit::VersionChanges.new(changes) }
  let(:path) { "/api/default-sort-topics" }
  let(:body) { JSON.parse(response.body) }
  let(:ids) { body.fetch("data").map { it.fetch("id") } }
  let(:error) { body.fetch("errors").sole }
  let(:cursor) do
    JsonApiKitSpec::DefaultSortTopicResource
      .order("created_at" => :desc)
      .locate(Topic.where(id: newest.id))
      .cursor
      .to_s
  end

  before do
    freeze_time(Date.new(2026, 9, 5))
    allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/default-sort-topics" => "json_api_kit_spec/default_sort_topics#index"
      get "/api/default-sort-topics/:id" => "json_api_kit_spec/default_sort_topics#show"
    end
    Rails.application.routes.disable_clear_and_finalize = false
  end

  after { Rails.application.reload_routes! }

  describe "a client edition" do
    subject(:document) do
      JsonApiKit::Document::Collection.for(
        {},
        resource: JsonApiKitSpec::DefaultSortTopicResource,
        client:,
      )
    end

    let(:client) do
      JsonApiKit::Client.new(
        guardian:,
        edition: JsonApiKit::Edition.for(JsonApiKit::Timeline::FIRST_RELEASE),
        urls:,
      )
    end
    let(:changes) do
      [
        Class
          .new(JsonApiKit::VersionChange) do
            version "2026-09-01"
            description "Topics change their title name and default sort."

            resource :topics do
              renamed_attribute from: :legacy_heading, to: :title
              changed_default_sort from: { created_at: :desc }
            end
          end
          .new(__FILE__),
      ]
    end
    let(:headings) do
      document.to_h.fetch(:data).map { it.fetch(:attributes).fetch("legacyHeading") }
    end

    it "uses the edition's vocabulary and default ordering" do
      expect(headings).to eq([newest.title, middle.title, oldest.title])
    end
  end

  describe "GET collection" do
    before { get path, headers: { "HTTP_API_VERSION" => version }, params: query }

    it "uses the historical default" do
      expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
    end

    context "when the pin includes the default change" do
      let(:version) { "2026-09-01" }

      it "uses the current default" do
        expect(ids).to eq([oldest.id, newest.id, middle.id].map(&:to_s))
      end
    end

    context "when the client supplies an explicit sort" do
      let(:query) { { "sort" => "title" } }

      it "uses the client's ordering" do
        expect(ids).to eq([oldest.id, newest.id, middle.id].map(&:to_s))
      end
    end

    context "when the client supplies an invalid sort" do
      let(:query) { { "sort" => "unknown" } }

      it "refuses the sort" do
        expect(error).to include("status" => "400", "title" => "No such sort")
      end
    end

    context "when the client follows a page link without a sort" do
      let(:query) { { "page" => { "size" => "1" } } }

      before { get body.fetch("links").fetch("next"), headers: { "HTTP_API_VERSION" => version } }

      it "continues the historical ordering" do
        expect(JSON.parse(response.body).fetch("data").map { it.fetch("id") }).to eq(
          [middle.id.to_s],
        )
      end
    end

    context "when a cursor matches the historical default" do
      let(:query) { { "page" => { "after" => cursor } } }

      it "accepts the cursor" do
        expect(ids).to eq([middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when an anchor matches the historical default" do
      let(:query) do
        { "page" => { "anchor" => { "createdAt" => middle.created_at.iso8601 }, "size" => "2" } }
      end

      it "enters the historical ordering at the anchor" do
        expect(ids).to eq([middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when an anchor matches only the current default" do
      let(:query) { { "page" => { "anchor" => { "title" => middle.title }, "size" => "2" } } }

      it "refuses the incompatible anchor" do
        expect(error).to include("status" => "400", "title" => "Anchor does not match the sort")
      end
    end

    context "when the new pin receives a cursor for the old default" do
      let(:version) { "2026-09-01" }
      let(:query) { { "page" => { "after" => cursor } } }

      it "refuses the incompatible cursor" do
        expect(error).to include("status" => "400", "title" => "Invalid cursor")
      end
    end

    context "when the client provides an empty sort string" do
      let(:query) { { "sort" => "" } }

      it "uses the historical default" do
        expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when the default has an old sort and resource name" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              version "2026-09-01"
              description "Discussions change their default sort."
              resource(:discussions) { changed_default_sort from: { posted_at: :desc } }
            end
            .new(__FILE__),
          Class
            .new(JsonApiKit::VersionChange) do
              version "2026-09-02"
              description "Discussions become topics with a renamed creation sort."
              renamed_type from: :discussions, to: :topics
              resource(:topics) { renamed_sort from: :posted_at, to: :created_at }
            end
            .new(__FILE__),
        ]
      end

      it "uses the translated historical ordering" do
        expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
      end

      it "retains the historical response type" do
        expect(body.fetch("data").map { it.fetch("type") }).to all(eq("discussions"))
      end
    end

    context "when the historical default has no named sort" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              version "2026-09-01"
              description "Topics acquire a default title sort."
              resource(:topics) { changed_default_sort from: {} }
            end
            .new(__FILE__),
        ]
      end

      it "uses only the uniqueness ordering" do
        expect(ids).to eq([oldest.id, middle.id, newest.id].map(&:to_s))
      end
    end
  end

  describe "GET related resources" do
    fab!(:first_post) { Fabricate(:post, topic: newest, post_number: 1) }
    fab!(:second_post) { Fabricate(:post, topic: newest, post_number: 2) }

    let(:path) { "/api/default-sort-topics/#{newest.id}" }
    let(:query) { { "include" => "posts" } }
    let(:post_ids) do
      body.fetch("data").fetch("relationships").fetch("posts").fetch("data").map { it.fetch("id") }
    end

    before { get path, headers: { "HTTP_API_VERSION" => version }, params: query }

    it "uses the related resource's historical default" do
      expect(post_ids).to eq([second_post.id, first_post.id].map(&:to_s))
    end

    context "when the pin includes the default change" do
      let(:version) { "2026-09-01" }

      it "uses the related resource's current default" do
        expect(post_ids).to eq([first_post.id, second_post.id].map(&:to_s))
      end
    end

    context "when the primary collection has an explicit sort" do
      let(:path) { "/api/default-sort-topics" }
      let(:query) { super().merge("sort" => "title") }
      let(:post_ids) do
        body
          .fetch("data")
          .detect { it["id"] == newest.id.to_s }
          .fetch("relationships")
          .fetch("posts")
          .fetch("data")
          .map { it.fetch("id") }
      end

      it "uses the related resource's own default" do
        expect(post_ids).to eq([second_post.id, first_post.id].map(&:to_s))
      end
    end
  end
end
