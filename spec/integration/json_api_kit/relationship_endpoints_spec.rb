# frozen_string_literal: true

module JsonApiKitSpec
  class EndpointUserResource < JsonApiKit::Resource
    model User
    type :users
    attribute :username
  end

  class EndpointPostResource < JsonApiKit::Resource
    model Post
    type :posts
    attribute :raw
    scope { Post.where(deleted_at: nil) }
    has_one :user, resource: EndpointUserResource
    sort :post_number
    default_sort post_number: :asc
    page default: 2
  end

  class EndpointTopicResource < JsonApiKit::Resource
    model Topic
    type :topics
    attribute :title
    scope { Topic.where(deleted_at: nil) }
    has_many :posts, resource: EndpointPostResource, readable: :is_admin?.to_proc
  end

  class TopicRelationshipsController < JsonApiKit::RelationshipsController
    resource EndpointTopicResource
  end

  class TopicRelatedResourcesController < JsonApiKit::RelatedResourcesController
    resource EndpointTopicResource
  end
end

RSpec.describe "JSON:API relationship endpoints", type: :request do
  fab!(:admin)
  fab!(:topic)
  fab!(:posts) { Fabricate.times(3, :post, topic:) }
  fab!(:deleted_post) { Fabricate(:post, topic:, deleted_at: 1.day.ago) }
  fab!(:unrelated_post, :post)

  let(:user) { admin }
  let(:owner_id) { topic.id }
  let(:relationship_name) { "posts" }
  let(:parameters) { {} }
  let(:headers) { { "HTTP_API_VERSION" => JsonApiKit::Timeline.current.to_s } }
  let(:body) { JSON.parse(response.body) }
  let(:identifiers) { posts.first(2).map { { "type" => "posts", "id" => it.id.to_s } } }

  before do
    host! Discourse.current_hostname
    sign_in(user)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/topics/:id/relationships/:relationship" =>
            "json_api_kit_spec/topic_relationships#show"
      get "/api/topics/:id/:relationship" => "json_api_kit_spec/topic_related_resources#index"
    end
    Rails.application.routes.disable_clear_and_finalize = false
  end

  after { Rails.application.reload_routes! }

  describe "GET /show" do
    let(:path) { "/api/topics/#{owner_id}/relationships/#{relationship_name}" }
    let(:next_page) { JSON.parse(response.body) }

    before { get(path, headers:, params: parameters) }

    it "returns identifiers within the owner and related resource scopes" do
      expect(body.fetch("data")).to eq(identifiers)
    end

    it "continues the relationship with the related resource's ordering" do
      get(body.dig("links", "next"), headers:)

      expect(next_page.fetch("data")).to eq([{ "type" => "posts", "id" => posts.last.id.to_s }])
    end

    context "when the requested page size exceeds the default" do
      let(:parameters) { super().merge(page: { size: 3 }) }

      it "returns the requested number of identifiers" do
        expect(body.fetch("data").size).to eq(3)
      end
    end

    context "when the request asks for item cursors" do
      let(:parameters) { super().merge(page: { itemCursors: true }) }

      it "includes a cursor with each resource identifier" do
        expect(body.fetch("data")).to all(
          include("meta" => { "page" => { "cursor" => a_kind_of(String) } }),
        )
      end
    end

    context "when the owner is outside its resource scope" do
      fab!(:deleted_topic) { Fabricate(:topic, deleted_at: 1.day.ago) }

      let(:owner_id) { deleted_topic.id }

      it { expect(response).to have_http_status(:not_found) }
    end

    context "when the owner does not exist" do
      let(:owner_id) { 0 }

      it { expect(response).to have_http_status(:not_found) }
    end

    context "when the relationship is not declared" do
      let(:relationship_name) { "title" }

      it { expect(response).to have_http_status(:not_found) }
    end

    context "when the relationship is not readable" do
      fab!(:visitor, :user)

      let(:user) { visitor }

      it { expect(response).to have_http_status(:not_found) }
    end

    context "when the relationship is empty" do
      fab!(:empty_topic, :topic)

      let(:owner_id) { empty_topic.id }

      it "returns empty linkage", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body.fetch("data")).to be_empty
      end
    end

    context "when the request asks for included resources" do
      let(:parameters) { super().merge(include: "user") }

      it "rejects include as an unsupported parameter", :aggregate_failures do
        expect(response).to have_http_status(:bad_request)
        expect(body.fetch("errors").sole).to include(
          "title" => "No such parameter",
          "source" => {
            "parameter" => "include",
          },
        )
      end

      context "when include is empty" do
        let(:parameters) { super().merge(include: "") }

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end

  describe "GET /index" do
    let(:path) { "/api/topics/#{owner_id}/#{relationship_name}" }
    let(:data) do
      posts
        .first(2)
        .map do |post|
          a_hash_including(
            "type" => "posts",
            "id" => post.id.to_s,
            "attributes" => {
              "raw" => post.raw,
            },
          )
        end
    end

    before { get(path, headers:, params: parameters) }

    it "returns the related resource objects" do
      expect(body.fetch("data")).to match(data)
    end

    context "when the request asks for included resources" do
      let(:parameters) { super().merge(include: "user") }
      let(:user_data) do
        posts
          .first(2)
          .map(&:user)
          .uniq
          .map do |user|
            a_hash_including(
              "type" => "users",
              "id" => user.id.to_s,
              "attributes" => {
                "username" => user.username,
              },
            )
          end
      end

      it "returns the requested users" do
        expect(body.fetch("included")).to contain_exactly(*user_data)
      end
    end

    context "when the request uses the related resource's fieldset" do
      let(:parameters) { super().merge(fields: { posts: "" }) }

      it "omits unrequested attributes" do
        expect(body.fetch("data")).to all(exclude("attributes"))
      end
    end
  end
end
