# frozen_string_literal: true

module JsonApiKitSpec
  class RemovedFilterTopicResource < JsonApiKit::Resource
    model Topic
    type :topics

    scope { |guardian| Topic.where(user_id: guardian.user&.id) }
    attribute :title
    attribute :closed
    filter :title
    sort :created_at
    default_sort created_at: :asc
  end

  class RemovedFilterTopicsController < JsonApiKit::BaseController
    resource RemovedFilterTopicResource
  end
end

RSpec.describe JsonApiKitSpec::RemovedFilterTopicsController, type: :request do
  fab!(:author, :user)
  fab!(:other_author, :user)
  fab!(:closed_topic) do
    Fabricate(:topic, user: author, closed: true, archived: false, created_at: Time.utc(2026, 8, 1))
  end
  fab!(:open_topic) do
    Fabricate(:topic, user: author, closed: false, archived: true, created_at: Time.utc(2026, 8, 2))
  end
  fab!(:other_topic) { Fabricate(:topic, user: other_author, closed: true) }

  let(:resource) { JsonApiKitSpec::RemovedFilterTopicResource }
  let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
  let(:parameters) { { filter: { closed: "true" } } }
  let(:body) { JSON.parse(response.body) }
  let(:ids) { body.fetch("data").map { it.fetch("id") } }
  let(:error) { body.fetch("errors").sole }
  let(:removal_class) do
    Class.new(JsonApiKit::VersionChange) do
      version "2026-09-10"
      description "Topics remove their closed and author filters."

      resource :topics do
        removed_filter :closed
        removed_filter(:by_author) { |scope, value| scope.where(user_id: value) }
        removed_filter(:matching_title) { |scope, value| scope.where(title: value) }
      end
    end
  end
  let(:removal) { removal_class.new(__FILE__) }
  let(:changes) { [removal] }
  let(:version_changes) { JsonApiKit::VersionChanges.new(changes) }

  before do
    freeze_time(Date.new(2026, 9, 18))
    sign_in(author)
    allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
    allow(described_class).to receive(:declared_resource).and_return(resource)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/removed-filter-topics" => "json_api_kit_spec/removed_filter_topics#index"
      get "/api/removed-filter-topics/:id" => "json_api_kit_spec/removed_filter_topics#show"
    end
    Rails.application.routes.disable_clear_and_finalize = false
  end

  after { Rails.application.reload_routes! }

  describe "#index" do
    before do
      get "/api/removed-filter-topics",
          headers: {
            "HTTP_API_VERSION" => version,
          },
          params: parameters
    end

    it "applies the removed equality filter within the resource's scope" do
      expect(ids).to eq([closed_topic.id.to_s])
    end

    it "preserves the resource's current declarations" do
      expect(resource.filter_names).to eq(["title"])
    end

    it "preserves the attribute with the same name" do
      expect(body.fetch("data").sole.fetch("attributes")).to include("closed" => true)
    end

    context "when no filter is requested" do
      let(:parameters) { {} }

      it "returns every row in the resource's scope" do
        expect(ids).to eq([closed_topic.id.to_s, open_topic.id.to_s])
      end
    end

    context "when the client follows a page link" do
      fab!(:later_closed_topic) do
        Fabricate(:topic, user: author, closed: true, created_at: Time.utc(2026, 8, 3))
      end

      let(:parameters) { super().merge(page: { size: 1 }) }
      let(:next_page_url) { JSON.parse(response.body).fetch("links").fetch("next") }

      before do
        get URI.parse(next_page_url).request_uri, headers: { "HTTP_API_VERSION" => version }
      end

      it "keeps the removed filter in the client's vocabulary" do
        expect(ids).to eq([later_closed_topic.id.to_s])
      end
    end

    context "when the pin includes the removal" do
      let(:version) { "2026-09-10" }

      it "refuses the removed filter" do
        expect(error).to include("status" => "400", "title" => "No such filter")
      end
    end

    context "when the request uses a custom removed filter" do
      let(:parameters) { { filter: { matchingTitle: closed_topic.title } } }

      it "runs the retained implementation" do
        expect(ids).to eq([closed_topic.id.to_s])
      end
    end

    context "when the removed filter selects rows outside the resource's scope" do
      let(:parameters) { { filter: { byAuthor: other_author.id } } }

      it "preserves the scope restriction" do
        expect(ids).to be_empty
      end
    end

    context "when the request uses a current filter" do
      let(:parameters) { { filter: { title: open_topic.title } } }

      it "uses the current declaration" do
        expect(ids).to eq([open_topic.id.to_s])
      end
    end

    context "when the request supplies an invalid filter value" do
      let(:parameters) { { filter: { byAuthor: { invalid: "value" } } } }

      it "reports the error in the client's vocabulary" do
        expect(error).to include(
          "status" => "400",
          "title" => "Invalid filter value",
          "source" => {
            "parameter" => "filter[byAuthor]",
          },
        )
      end
    end

    context "when the filter was renamed before removal" do
      let(:parameters) { { filter: { isClosed: "true" } } }
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              version "2026-09-05"
              resource(:topics) { renamed_filter from: :is_closed, to: :closed }
            end
            .new(__FILE__),
          removal,
        ]
      end

      it "resolves the earlier name to the retained definition" do
        expect(ids).to eq([closed_topic.id.to_s])
      end
    end

    context "when the current resource reuses the removed name" do
      let(:resource) do
        Class.new(super()) { filter(:closed) { |scope, value| scope.where(archived: value) } }
      end

      it "keeps the retained behavior for the older pin" do
        expect(ids).to eq([closed_topic.id.to_s])
      end

      context "when the pin includes the removal" do
        let(:version) { "2026-09-10" }

        it "uses the current implementation" do
          expect(ids).to eq([open_topic.id.to_s])
        end
      end
    end

    context "when a later rename reuses the removed spelling" do
      let(:resource) { Class.new(super()) { filter :archived } }
      let(:changes) do
        [
          removal,
          Class
            .new(JsonApiKit::VersionChange) do
              version "2026-09-15"
              resource(:topics) { renamed_filter from: :closed, to: :archived }
            end
            .new(__FILE__),
        ]
      end

      it "keeps the request bound to the removed implementation" do
        expect(ids).to eq([closed_topic.id.to_s])
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

      it "restores the filter for the renamed resource" do
        expect(ids).to eq([closed_topic.id.to_s])
      end
    end

    context "when the resource type changes in the removal's own change" do
      let(:removal_class) { super().tap { it.renamed_type from: :discussions, to: :topics } }

      it "uses the declaration's type after the rename" do
        expect(ids).to eq([closed_topic.id.to_s])
      end
    end

    context "when the same name is removed more than once" do
      let(:changes) do
        [
          removal,
          Class
            .new(JsonApiKit::VersionChange) do
              version "2026-09-15"
              resource(:topics) do
                removed_filter(:closed) { |scope, value| scope.where(archived: value) }
              end
            end
            .new(__FILE__),
        ]
      end

      it "uses the first removed implementation for the oldest pin" do
        expect(ids).to eq([closed_topic.id.to_s])
      end

      context "when the pin is between the removals" do
        let(:version) { "2026-09-10" }

        it "uses the second removed implementation" do
          expect(ids).to eq([open_topic.id.to_s])
        end
      end

      context "when the pin includes both removals" do
        let(:version) { "2026-09-15" }

        it "refuses the filter" do
          expect(error).to include("status" => "400", "title" => "No such filter")
        end
      end
    end
  end

  describe "#show" do
    before do
      get "/api/removed-filter-topics/#{closed_topic.id}",
          headers: {
            "HTTP_API_VERSION" => version,
          },
          params: parameters
    end

    it "refuses collection parameters on an individual request" do
      expect(error).to include("status" => "400", "source" => { "parameter" => "filter" })
    end
  end
end
