# frozen_string_literal: true

module JsonApiKitSpec
  class CollectionTopicResource < JsonApiKit::Resource
    model Topic
    type :topics

    scope { |guardian| Topic.where(user_id: guardian.user&.id) }
    attribute :title
    sort :created_at
    default_sort created_at: :asc
    filter :closed
    filter :visible

    collection :archive do
      filter(:closed) { |scope, value| scope.where(archived: value) }
      filter :visible
      filter :archetype
    end
  end

  class CollectionTopicsController < JsonApiKit::BaseController
    resource CollectionTopicResource
  end

  class ArchivedTopicsController < JsonApiKit::BaseController
    resource CollectionTopicResource.collection(:archive)
  end
end

RSpec.describe "JSON:API named collections", type: :request do
  fab!(:author, :user)
  fab!(:closed_topic) do
    Fabricate(:topic, user: author, closed: true, archived: false, created_at: Time.utc(2026, 8, 1))
  end
  fab!(:archived_topic) do
    Fabricate(:topic, user: author, closed: false, archived: true, created_at: Time.utc(2026, 8, 2))
  end
  fab!(:other_topic) { Fabricate(:topic, closed: true, archived: true) }

  let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
  let(:body) { JSON.parse(response.body) }
  let(:ids) { body.fetch("data").map { it.fetch("id") } }
  let(:error) { body.fetch("errors").sole }
  let(:change_class) do
    Class.new(JsonApiKit::VersionChange) do
      version "2026-09-10"
      description "The archive drops its closed and hidden filters."

      resource :topics do
        collection :archive do
          removed_filter(:closed) { |scope, _value| scope.none }
          renamed_filter from: :hidden, to: :visible
        end
      end
    end
  end
  let(:changes) { [change_class.new(__FILE__)] }

  before do
    freeze_time(Date.new(2026, 9, 18))
    sign_in(author)
    allow(JsonApiKit::VersionChanges).to receive(:core).and_return(
      JsonApiKit::VersionChanges.new(changes),
    )
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/collection-topics" => "json_api_kit_spec/collection_topics#index"
      get "/api/collection-topics/archive" => "json_api_kit_spec/archived_topics#index"
    end
    Rails.application.routes.disable_clear_and_finalize = false
  end

  after { Rails.application.reload_routes! }

  def fetch(path, parameters)
    get path, headers: { "HTTP_API_VERSION" => version }, params: parameters
  end

  context "with the pin that includes the change" do
    let(:version) { "2026-09-10" }

    it "filters the browsing listing with its own declaration" do
      fetch("/api/collection-topics", filter: { closed: "true" })

      expect(ids).to eq([closed_topic.id.to_s])
    end

    it "filters the collection with its declaration of the same name" do
      fetch("/api/collection-topics/archive", filter: { closed: "true" })

      expect(ids).to eq([archived_topic.id.to_s])
    end

    it "refuses on the browsing listing a filter only the collection declares" do
      fetch("/api/collection-topics", filter: { archetype: "regular" })

      expect(error).to include("status" => "400", "title" => "No such filter")
    end

    it "lists the collection within the resource's scope, as records of the resource's type" do
      fetch("/api/collection-topics/archive", {})

      expect(body.fetch("data").map { it.slice("type", "id", "links") }).to eq(
        [closed_topic, archived_topic].map do |topic|
          {
            "type" => "topics",
            "id" => topic.id.to_s,
            "links" => {
              "self" => "http://test.localhost/api/topics/#{topic.id}",
            },
          }
        end,
      )
    end
  end

  context "with a pin from before the change" do
    it "keeps the removed filter for the collection" do
      fetch("/api/collection-topics/archive", filter: { closed: "true" })

      expect(ids).to be_empty
    end

    it "leaves the browsing listing's filter of the same name alone" do
      fetch("/api/collection-topics", filter: { closed: "true" })

      expect(ids).to eq([closed_topic.id.to_s])
    end

    it "takes the collection's earlier spelling of a renamed filter" do
      fetch("/api/collection-topics/archive", filter: { hidden: "true" })

      expect(ids).to eq([closed_topic.id.to_s, archived_topic.id.to_s])
    end

    it "keeps that spelling out of the browsing listing" do
      fetch("/api/collection-topics", filter: { hidden: "true" })

      expect(error).to include("status" => "400", "title" => "No such filter")
    end
  end
end
