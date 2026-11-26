# frozen_string_literal: true

module JsonApiKitSpec
  class EndpointTopic < ::Topic
    has_one :latest_post,
            -> { where(deleted_at: nil).order(post_number: :desc) },
            class_name: "Post",
            foreign_key: :topic_id
  end

  class EndpointCategoryResource < JsonApiKit::Resource
    model Category
    type :categories
    attribute :name
    filter :name
  end

  class EndpointUserResource < JsonApiKit::Resource
    model User
    type :users
    attribute :username
    filter :username
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

  class EndpointLatestPostResource < EndpointPostResource
    model Post
    type :posts
    default_sort post_number: :desc
  end

  class EndpointTopicResource < JsonApiKit::Resource
    model EndpointTopic
    type :topics
    attribute :title
    scope { EndpointTopic.where(deleted_at: nil) }
    has_many :posts, resource: EndpointPostResource, readable: :is_admin?.to_proc
    has_one :category, resource: EndpointCategoryResource
    has_one :latest_post, resource: EndpointLatestPostResource
    includes "latest_post.user"
    includes "posts.user"
    filter :id
  end

  class EndpointOwnerTopicsController < JsonApiKit::BaseController
    resource EndpointTopicResource
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
      get "/api/topics" => "json_api_kit_spec/endpoint_owner_topics#index"
      get "/api/topics/:id/latest-post" => "json_api_kit_spec/topic_related_resources#show",
          :defaults => {
            relationship: "latest-post",
          }
      get "/api/topics/:id/category" => "json_api_kit_spec/topic_related_resources#show",
          :defaults => {
            relationship: "category",
          }
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

    context "when the relationship is to-one" do
      let(:relationship_name) { "category" }

      it "returns a single identifier" do
        expect(body.fetch("data")).to eq("type" => "categories", "id" => topic.category_id.to_s)
      end

      context "when the relationship is empty" do
        fab!(:private_topic, :private_message_topic)

        let(:owner_id) { private_topic.id }

        it "returns null linkage", :aggregate_failures do
          expect(response).to have_http_status(:ok)
          expect(body.fetch("data")).to be_nil
        end
      end

      context "when the request asks for included resources" do
        let(:parameters) { { include: "" } }

        it { expect(response).to have_http_status(:bad_request) }
      end
    end

    context "when the to-one relationship selects from several posts" do
      let(:relationship_name) { "latest-post" }

      it "returns the selected identifier" do
        expect(body.fetch("data")).to eq("type" => "posts", "id" => posts.last.id.to_s)
      end
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

  describe "GET /category" do
    let(:path) { "/api/topics/#{owner_id}/category" }

    before { get(path, headers:, params: parameters) }

    it "returns a single resource" do
      expect(body.fetch("data")).to include(
        "type" => "categories",
        "id" => topic.category_id.to_s,
        "attributes" => {
          "name" => topic.category.name,
        },
      )
    end

    context "when the relationship is empty" do
      fab!(:private_topic, :private_message_topic)

      let(:owner_id) { private_topic.id }

      it "returns null primary data", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(body.fetch("data")).to be_nil
      end
    end

    context "when the filter excludes the related resource" do
      let(:parameters) { { filter: { name: "Another category" } } }

      it "returns null primary data" do
        expect(body.fetch("data")).to be_nil
      end
    end
  end

  describe "GET /latest-post" do
    let(:path) { "/api/topics/#{owner_id}/latest-post" }
    let(:parameters) { { include: "user" } }

    before { get(path, headers:, params: parameters) }

    it "returns the selected post and its author", :aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(body.dig("data", "id")).to eq(posts.last.id.to_s)
      expect(body.fetch("included")).to contain_exactly(
        a_hash_including("type" => "users", "id" => posts.last.user_id.to_s),
      )
    end

    context "when the fieldset omits the owner key" do
      let(:parameters) { super().merge(fields: { posts: "raw,user" }) }

      it "returns the selected post" do
        expect(body.fetch("data")).to include(
          "id" => posts.last.id.to_s,
          "attributes" => {
            "raw" => posts.last.raw,
          },
        )
      end
    end
  end

  describe "GET /topics with a to-one inclusion" do
    fab!(:another_topic, :topic)
    fab!(:another_posts) { Fabricate.times(2, :post, topic: another_topic) }

    let(:parameters) do
      { include: "latestPost.user", filter: { id: [topic.id, another_topic.id] } }
    end
    let(:included_identifiers) { body.fetch("included").map { it.slice("type", "id") } }

    before { get("/api/topics", headers:, params: parameters) }

    it "includes only each selected post and its author" do
      expect(included_identifiers).to contain_exactly(
        { "type" => "posts", "id" => posts.last.id.to_s },
        { "type" => "posts", "id" => another_posts.last.id.to_s },
        { "type" => "users", "id" => posts.last.user_id.to_s },
        { "type" => "users", "id" => another_posts.last.user_id.to_s },
      )
    end
  end

  describe "GET /topics with an empty nested filter list" do
    before { get("/api/topics?include=posts.user&filter[posts.user.username][]", headers:) }

    it "rejects the filter before generating relationship links", :aggregate_failures do
      expect(response).to have_http_status(:bad_request)
      expect(body.fetch("errors")).to contain_exactly(
        a_hash_including(
          "title" => "Invalid filter value",
          "detail" => "filter[posts.user.username] must be a value or a non-empty list of values.",
          "source" => {
            "parameter" => "filter[posts.user.username]",
          },
        ),
      )
    end
  end

  describe "following a related link with a nested filter" do
    let(:username) { posts.first.user.username }
    let(:parameters) do
      { include: "posts.user", filter: { :id => topic.id, "posts.user.username" => username } }
    end
    let(:related_url) { body.dig("data", 0, "relationships", "posts", "links", "related") }
    let(:related_body) { JSON.parse(response.body) }
    let(:related_ids) { related_body.fetch("data").map { it.fetch("id") } }
    let(:first_page_ids) { posts.first(2).map { it.id.to_s } }
    let(:included_users) { related_body.fetch("included") }

    before do
      get("/api/topics", headers:, params: parameters)
      get(related_url, headers:, params: { include: "user" })
    end

    it "preserves the selected author" do
      expect(included_users).to contain_exactly(
        a_hash_including("type" => "users", "id" => posts.first.user_id.to_s),
      )
    end

    context "when no author matches the filter" do
      let(:username) { "#{super()}_missing" }

      it "keeps the related posts without including authors", :aggregate_failures do
        expect(related_ids).to eq(first_page_ids)
        expect(included_users).to be_empty
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
