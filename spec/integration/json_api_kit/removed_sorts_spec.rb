# frozen_string_literal: true

module JsonApiKitSpec
  class RemovedSortPostResource < JsonApiKit::Resource
    model Post
    type :posts
    attribute :post_number
  end

  class RemovedSortTopicResource < JsonApiKit::Resource
    model Topic
    type :topics

    scope { |guardian| Topic.where(user_id: guardian.user&.id) }
    attribute :title
    attribute :created_at
    sort :title
    default_sort title: :asc
    anchor :created_at
    anchor :title
    anchor :id
    page default: 10, max: 20
    has_many :posts, resource: RemovedSortPostResource
  end

  class RemovedSortTopicsController < JsonApiKit::BaseController
    resource RemovedSortTopicResource
  end
end

RSpec.describe JsonApiKitSpec::RemovedSortTopicsController, type: :request do
  fab!(:author, :user)
  fab!(:oldest_category) { Fabricate(:category, name: "M category") }
  fab!(:middle_category) { Fabricate(:category, name: "A category") }
  fab!(:newest_category) { Fabricate(:category, name: "Z category") }
  fab!(:oldest) do
    Fabricate(
      :topic,
      user: author,
      category: oldest_category,
      title: "A first topic to sort",
      created_at: Time.utc(2026, 8, 1),
      last_posted_at: Time.utc(2026, 8, 1),
    )
  end
  fab!(:middle) do
    Fabricate(
      :topic,
      user: author,
      category: middle_category,
      title: "Z middle topic to sort",
      created_at: Time.utc(2026, 8, 2),
      last_posted_at: nil,
    )
  end
  fab!(:newest) do
    Fabricate(
      :topic,
      user: author,
      category: newest_category,
      title: "M last topic to sort",
      created_at: Time.utc(2026, 8, 3),
      last_posted_at: Time.utc(2026, 8, 3),
    )
  end
  fab!(:other_topic) { Fabricate(:topic, created_at: Time.utc(2026, 8, 4)) }

  let(:resource) { JsonApiKitSpec::RemovedSortTopicResource }
  let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
  let(:parameters) { { sort: "-createdAt" } }
  let(:body) { JSON.parse(response.body) }
  let(:ids) { body.fetch("data").map { it.fetch("id") } }
  let(:error) { body.fetch("errors").sole }
  let(:removal_class) do
    Class.new(JsonApiKit::VersionChange) do
      version "2026-09-10"
      description "Topics remove their creation sort."

      resource :topics do
        removed_sort :created_at
        changed_default_sort from: { created_at: :desc }
      end
    end
  end
  let(:removal) { removal_class.new(__FILE__) }
  let(:changes) { [removal] }
  let(:version_changes) { JsonApiKit::VersionChanges.new(changes) }
  let(:original_resource) { Class.new(resource) { sort :created_at } }
  let(:original_cursor) do
    original_resource.order("created_at" => :desc).locate(Topic.where(id: newest.id)).cursor.to_s
  end

  before do
    freeze_time(Date.new(2026, 9, 18))
    sign_in(author)
    allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
    allow(described_class).to receive(:declared_resource).and_return(resource)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/removed-sort-topics" => "json_api_kit_spec/removed_sort_topics#index"
      get "/api/removed-sort-topics/:id" => "json_api_kit_spec/removed_sort_topics#show"
    end
    Rails.application.routes.disable_clear_and_finalize = false
  end

  after { Rails.application.reload_routes! }

  describe "#index" do
    before do
      get "/api/removed-sort-topics", headers: { "HTTP_API_VERSION" => version }, params: parameters
    end

    it "uses the retained sort within the authorized scope" do
      expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
    end

    it "preserves the current declarations" do
      expect(resource.sort_names).to eq(["title"])
    end

    context "when the client requests ascending order" do
      let(:parameters) { { sort: "createdAt" } }

      it "uses the requested direction" do
        expect(ids).to eq([oldest.id, middle.id, newest.id].map(&:to_s))
      end
    end

    context "when the client omits the sort" do
      let(:parameters) { {} }

      it "uses the removed sort as the historical default" do
        expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
      end

      context "when the pin includes the removal" do
        let(:version) { "2026-09-10" }

        it "uses the current default" do
          expect(ids).to eq([oldest.id, newest.id, middle.id].map(&:to_s))
        end
      end
    end

    context "when the pin includes the removal" do
      let(:version) { "2026-09-10" }

      it "rejects the removed sort in the client's vocabulary" do
        expect(error).to include(
          "status" => "400",
          "title" => "No such sort",
          "detail" => "There is no sort named createdAt.",
        )
      end
    end

    context "when the client follows a page link" do
      let(:parameters) { super().merge(page: { size: 1 }) }
      let(:next_page) { URI.parse(body.fetch("links").fetch("next")).request_uri }

      before { get next_page, headers: { "HTTP_API_VERSION" => version } }

      it "continues the retained ordering" do
        expect(JSON.parse(response.body).fetch("data").map { it.fetch("id") }).to eq(
          [middle.id.to_s],
        )
      end
    end

    context "when the cursor predates the removal" do
      let(:parameters) { super().merge(page: { after: original_cursor }) }

      it "accepts the original sort's cursor" do
        expect(ids).to eq([middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when the anchor matches the removed sort" do
      let(:parameters) do
        super().merge(page: { anchor: { createdAt: middle.created_at.iso8601 }, size: 2 })
      end

      it "enters the retained ordering at the anchor" do
        expect(ids).to eq([middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when the anchor matches only the current sort" do
      let(:parameters) { super().merge(page: { anchor: { title: middle.title }, size: 2 }) }

      it "rejects the incompatible anchor" do
        expect(error).to include("status" => "400", "title" => "Anchor does not match the sort")
      end
    end

    context "when the client uses the identity anchor" do
      let(:parameters) { super().merge(page: { anchor: { id: middle.id }, size: 2 }) }

      it "locates the row within the retained ordering" do
        expect(ids).to eq([middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when the removed sort has an aliased column" do
      let(:parameters) { { sort: "-postedAt" } }
      let(:removal_class) do
        Class.new(JsonApiKit::VersionChange) do
          version "2026-09-10"
          resource(:topics) { removed_sort :posted_at, column: :created_at }
        end
      end

      it "orders by the retained column" do
        expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when the removed sort uses a SQL expression" do
      let(:parameters) { { sort: "titleLength", fields: { topics: "title" } } }
      let(:removal_class) do
        Class.new(JsonApiKit::VersionChange) do
          version "2026-09-10"
          resource(:topics) { removed_sort :title_length, sql: "LENGTH(topics.title)" }
        end
      end

      it "orders by the retained expression with a sparse fieldset" do
        expect(ids).to eq([newest.id, oldest.id, middle.id].map(&:to_s))
      end
    end

    context "when the removed sort has explicit joins" do
      let(:parameters) { { sort: "categoryName" } }
      let(:removal_class) do
        Class.new(JsonApiKit::VersionChange) do
          version "2026-09-10"
          resource(:topics) do
            removed_sort :category_name, sql: "categories.name", joins: :category
          end
        end
      end

      it "applies the retained joins" do
        expect(ids).to eq([middle.id, oldest.id, newest.id].map(&:to_s))
      end
    end

    context "when the removed sort names a related column" do
      let(:parameters) { { sort: "category.name" } }
      let(:removal_class) do
        Class.new(JsonApiKit::VersionChange) do
          version "2026-09-10"
          resource(:topics) { removed_sort "category.name" }
        end
      end

      it "preserves the related sort's lookup and projection" do
        expect(ids).to eq([middle.id, oldest.id, newest.id].map(&:to_s))
      end
    end

    context "when the removed sort has explicit null placement" do
      let(:parameters) { { sort: "lastPostedAt" } }
      let(:removal_class) do
        Class.new(JsonApiKit::VersionChange) do
          version "2026-09-10"
          resource(:topics) { removed_sort :last_posted_at, nulls: :first }
        end
      end

      it "places null values at the declared end" do
        expect(ids).to eq([middle.id, oldest.id, newest.id].map(&:to_s))
      end

      context "when the client follows a page link across the null segment" do
        let(:parameters) { super().merge(page: { size: 1 }) }
        let(:next_page) { URI.parse(body.fetch("links").fetch("next")).request_uri }

        before { get next_page, headers: { "HTTP_API_VERSION" => version } }

        it "continues into the segment with values" do
          expect(JSON.parse(response.body).fetch("data").map { it.fetch("id") }).to eq(
            [oldest.id.to_s],
          )
        end
      end
    end

    context "when the client follows a page link with a historical default" do
      let(:parameters) { { page: { size: 1 } } }
      let(:next_page) { URI.parse(body.fetch("links").fetch("next")).request_uri }

      before { get next_page, headers: { "HTTP_API_VERSION" => version } }

      it "continues the default ordering without an explicit sort" do
        expect(JSON.parse(response.body).fetch("data").map { it.fetch("id") }).to eq(
          [middle.id.to_s],
        )
      end
    end

    context "when a later rename reuses the removed spelling" do
      let(:resource) { Class.new(super()) { sort :recency, column: :title } }
      let(:changes) do
        [
          removal,
          Class
            .new(JsonApiKit::VersionChange) do
              version "2026-09-15"
              resource(:topics) { renamed_sort from: :created_at, to: :recency }
            end
            .new(__FILE__),
        ]
      end

      it "keeps the old request bound to its retained implementation" do
        expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when the resource type changes in the removal's own change" do
      let(:removal_class) { super().tap { it.renamed_type from: :discussions, to: :topics } }

      it "uses the declaration's type after the rename" do
        expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when the same sort name is removed more than once" do
      let(:changes) do
        [
          removal,
          Class
            .new(JsonApiKit::VersionChange) do
              version "2026-09-15"
              resource(:topics) { removed_sort :created_at, column: :title }
            end
            .new(__FILE__),
        ]
      end

      it "uses the first implementation for the oldest pin" do
        expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
      end

      context "when the pin is between removals" do
        let(:version) { "2026-09-10" }

        it "uses the second implementation" do
          expect(ids).to eq([middle.id, newest.id, oldest.id].map(&:to_s))
        end
      end

      context "when the pin includes both removals" do
        let(:version) { "2026-09-15" }

        it "rejects the removed sort" do
          expect(error).to include("status" => "400", "title" => "No such sort")
        end
      end
    end

    context "when the current resource reuses the removed name" do
      let(:resource) { Class.new(super()) { sort :created_at, column: :title } }

      it "keeps the old implementation for the older pin" do
        expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
      end

      context "when the pin includes the removal" do
        let(:version) { "2026-09-10" }

        it "uses the current implementation" do
          expect(ids).to eq([middle.id, newest.id, oldest.id].map(&:to_s))
        end
      end
    end

    context "when the sort was renamed before removal" do
      let(:parameters) { { sort: "-postedAt" } }
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              version "2026-09-05"
              resource(:topics) { renamed_sort from: :posted_at, to: :created_at }
            end
            .new(__FILE__),
          removal,
        ]
      end

      it "resolves the earlier name to the retained implementation" do
        expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when the resource type changes after removal" do
      let(:resource) { Class.new(super()) { type :threads } }
      let(:changes) do
        [
          removal,
          Class
            .new(JsonApiKit::VersionChange) do
              version "2026-09-15"
              renamed_type from: :topics, to: :threads
            end
            .new(__FILE__),
        ]
      end

      it "restores the sort for the renamed resource" do
        expect(ids).to eq([newest.id, middle.id, oldest.id].map(&:to_s))
      end
    end

    context "when related resources have removed default sorts" do
      fab!(:first_post) { Fabricate(:post, topic: newest, post_number: 1) }
      fab!(:second_post) { Fabricate(:post, topic: newest, post_number: 2) }

      let(:parameters) { super().merge(include: "posts") }
      let(:removal_class) do
        super().tap do |change|
          change.resource :posts do
            removed_sort :post_number
            changed_default_sort from: { post_number: :desc }
          end
        end
      end
      let(:post_ids) do
        body.fetch("data").first.dig("relationships", "posts", "data").map { it.fetch("id") }
      end

      it "uses the related resource's retained ordering" do
        expect(post_ids).to eq([second_post.id, first_post.id].map(&:to_s))
      end
    end
  end
end
