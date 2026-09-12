# frozen_string_literal: true

require_relative "support"

module JsonApiKitSpec
  class RelationshipUser < ::User
    has_many :valid_groups, through: :group_users, source: :group
  end

  class RelationshipTopic < ::Topic
    belongs_to :writer, class_name: "JsonApiKitSpec::RelationshipUser", foreign_key: :user_id
  end

  class RelationshipGroupResource < JsonApiKit::Resource
    model Group
    type :groups
    attribute :name
  end

  class RelationshipUserResource < JsonApiKit::Resource
    model RelationshipUser
    type :users
    attribute :username
    has_many :valid_groups, resource: RelationshipGroupResource
  end

  RelationshipGroupResource.has_many(:users, resource: RelationshipUserResource)

  class RelationshipTopicResource < JsonApiKit::Resource
    model RelationshipTopic
    type :topics
    attribute :title
    sort :created_at
    sort "writer.username"
    default_sort created_at: :desc
    has_one :writer, resource: RelationshipUserResource
    has_one :category, resource: CategoryResource
    includes "writer.valid_groups"
  end

  class RelationshipTopicsController < JsonApiKit::BaseController
    resource RelationshipTopicResource

    def writer
      render_document(
        JsonApiKit::Document::Individual.for(
          topic.user_id,
          request.query_parameters,
          resource: RelationshipUserResource,
          client:,
        ),
      )
    end

    def writer_linkage
      render json: {
               data: {
                 type: glossary.member_type("users"),
                 id: topic.user_id.to_s,
               },
             },
             content_type: JsonApiKit::Pagination::Profile::MEDIA_TYPE
    end

    private

    def topic = RelationshipTopic.find(params[:id])
  end

  class RelationshipUsersController < JsonApiKit::BaseController
    resource RelationshipUserResource

    def valid_groups
      render_document(
        JsonApiKit::Document::Collection.for(
          request.query_parameters,
          resource: RelationshipGroupResource,
          client:,
          scoped_to: user.valid_groups,
        ),
      )
    end

    def valid_groups_linkage
      render json: {
               data: group_identifiers,
             },
             content_type: JsonApiKit::Pagination::Profile::MEDIA_TYPE
    end

    private

    def user = RelationshipUser.find(params[:id])

    def group_identifiers
      user.valid_groups.map { { type: glossary.member_type("groups"), id: it.id.to_s } }
    end
  end

  class RenameTopicAuthorToWriter < JsonApiKit::VersionChange
    version "2026-09-01"
    description "The author relationship becomes writer."

    resource :topics do
      renamed_relationship from: :author, to: :writer
    end
  end

  class RenameUserGroupsToValidGroups < JsonApiKit::VersionChange
    version "2026-09-02"
    description "The groups relationship becomes valid_groups."

    resource :users do
      renamed_relationship from: :groups, to: :valid_groups
    end
  end
end

RSpec.describe "JSON:API relationship renames", type: :request do
  include_context "with a listing of topics"

  let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
  let(:changes) do
    [
      JsonApiKitSpec::RenameTopicAuthorToWriter.new(__FILE__),
      JsonApiKitSpec::RenameUserGroupsToValidGroups.new(__FILE__),
    ]
  end
  let(:version_changes) { JsonApiKit::VersionChanges.new(changes) }
  let(:query) { { "include" => "author.groups" } }
  let(:body) { JSON.parse(response.body) }
  let(:primary_resource) { body.fetch("data").first }
  let(:author_resource) do
    body.fetch("included").detect { it["type"] == "users" && it["id"] == newest.user_id.to_s }
  end
  let(:error) { body.fetch("errors").sole }

  fab!(:group)

  before do
    group.add(newest.user)
    freeze_time(Date.new(2026, 9, 3))
    allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/topics" => "json_api_kit_spec/relationship_topics#index"
      get "/api/topics/:id/writer" => "json_api_kit_spec/relationship_topics#writer"
      get "/api/topics/:id/relationships/writer" =>
            "json_api_kit_spec/relationship_topics#writer_linkage"
      get "/api/users/:id/valid-groups" => "json_api_kit_spec/relationship_users#valid_groups"
      get "/api/users/:id/relationships/valid-groups" =>
            "json_api_kit_spec/relationship_users#valid_groups_linkage"
    end
    Rails.application.routes.disable_clear_and_finalize = false
    get "/api/topics", headers: { "HTTP_API_VERSION" => version }, params: query
  end

  after { Rails.application.reload_routes! }

  it "uses the historical name of the to-one relationship" do
    expect(primary_resource.fetch("relationships")).to include(
      "author" => a_hash_including("data" => { "type" => "users", "id" => newest.user_id.to_s }),
    )
  end

  it "uses the historical name of the to-many relationship" do
    expect(author_resource.dig("relationships", "groups", "data")).to include(
      "type" => "groups",
      "id" => group.id.to_s,
    )
  end

  it "includes the resources reached through both renamed segments" do
    expect(body.fetch("included")).to include(
      a_hash_including("type" => "users", "id" => newest.user_id.to_s),
      a_hash_including("type" => "groups", "id" => group.id.to_s),
    )
  end

  context "when the request selects renamed relationships in fieldsets" do
    let(:query) { super().merge("fields" => { "topics" => "author", "users" => "groups" }) }

    it "selects the historical to-one relationship" do
      expect(primary_resource.fetch("relationships").keys).to contain_exactly("author")
    end

    it "selects the historical to-many relationship" do
      expect(author_resource.fetch("relationships").keys).to contain_exactly("groups")
    end

    it "excludes unselected attributes" do
      expect(author_resource).not_to have_key("attributes")
    end
  end

  context "when the request includes an unrelated relationship" do
    let(:query) { super().merge("include" => "author.groups,category") }

    it "preserves the unrelated name" do
      expect(primary_resource.fetch("relationships").keys).to contain_exactly("author", "category")
    end
  end

  context "when the client follows the to-one related link" do
    before do
      get primary_resource.dig("relationships", "author", "links", "related"),
          headers: {
            "HTTP_API_VERSION" => version,
          }
    end

    it "serves the related resource through the current route" do
      expect(JSON.parse(response.body).fetch("data")).to include(
        "type" => "users",
        "id" => newest.user_id.to_s,
      )
    end
  end

  context "when the client follows the to-one linkage link" do
    before do
      get primary_resource.dig("relationships", "author", "links", "self"),
          headers: {
            "HTTP_API_VERSION" => version,
          }
    end

    it "serves linkage through the current route" do
      expect(JSON.parse(response.body).fetch("data")).to eq(
        "type" => "users",
        "id" => newest.user_id.to_s,
      )
    end
  end

  context "when the client follows the to-many related link" do
    before do
      get author_resource.dig("relationships", "groups", "links", "related"),
          headers: {
            "HTTP_API_VERSION" => version,
          }
    end

    it "serves the collection through the current kebab-case route" do
      expect(JSON.parse(response.body).fetch("data")).to include(
        a_hash_including("type" => "groups", "id" => group.id.to_s),
      )
    end
  end

  context "when the client follows the to-many linkage link" do
    before do
      get author_resource.dig("relationships", "groups", "links", "self"),
          headers: {
            "HTTP_API_VERSION" => version,
          }
    end

    it "serves linkage through the current kebab-case route" do
      expect(JSON.parse(response.body).fetch("data")).to include(
        "type" => "groups",
        "id" => group.id.to_s,
      )
    end
  end

  context "when the request uses a newer name in the first segment" do
    let(:query) { { "include" => "writer.groups" } }

    it "corrects that segment" do
      expect(error).to include(
        "detail" => "Use author, not writer.",
        "source" => {
          "parameter" => "include",
        },
      )
    end
  end

  context "when the request uses a newer name in the second segment" do
    let(:query) { { "include" => "author.validGroups" } }

    it "corrects the segment in the target resource's vocabulary" do
      expect(error).to include(
        "detail" => "Use groups, not validGroups.",
        "source" => {
          "parameter" => "include",
        },
      )
    end
  end

  context "when the request uses a newer relationship name in a fieldset" do
    let(:query) { super().merge("fields" => { "users" => "validGroups" }) }

    it "corrects the field name" do
      expect(error).to include(
        "detail" => "Use groups, not validGroups.",
        "source" => {
          "parameter" => "fields[users]",
        },
      )
    end
  end

  context "when a later segment does not exist" do
    let(:query) { { "include" => "author.unknownGroups" } }

    it "reports the original client path" do
      expect(error).to include(
        "detail" => "There is no relationship path named author.unknownGroups.",
        "source" => {
          "parameter" => "include",
        },
      )
    end
  end

  context "when the translated path exists but is not allowed" do
    let(:query) { { "include" => "author.groups.users" } }

    it "reports the disallowed path in the client's vocabulary" do
      expect(error).to include(
        "detail" => "There is no relationship path named author.groups.users.",
        "source" => {
          "parameter" => "include",
        },
      )
    end
  end

  context "when a long cyclic path is not allowed" do
    let(:query) { { "include" => "author.#{Array.new(1500, "groups.users").join(".")}" } }

    it "rejects the path without exhausting the stack" do
      expect(response).to have_http_status(:bad_request)
    end
  end

  context "when the request uses the historical relationship in a sort name" do
    let(:query) { super().merge("sort" => "author.username") }

    it "requires an explicit sort rename" do
      expect(error).to include("detail" => "There is no sort named author.username.")
    end
  end

  context "when the pin follows the first rename" do
    let(:version) { "2026-09-01" }
    let(:query) { { "include" => "writer.groups" } }

    it "uses the current first segment" do
      expect(primary_resource.fetch("relationships").keys).to contain_exactly("writer")
    end

    it "uses the historical second segment" do
      expect(author_resource.fetch("relationships").keys).to contain_exactly("groups")
    end
  end

  context "when the pin follows both renames" do
    let(:version) { "2026-09-02" }
    let(:query) { { "include" => "writer.validGroups" } }

    it "uses the current second segment with camel casing" do
      expect(author_resource.fetch("relationships").keys).to contain_exactly("validGroups")
    end
  end

  context "when the types also have historical names" do
    let(:changes) { [type_change, *super()] }
    let(:type_change) do
      Class
        .new(JsonApiKit::VersionChange) do
          version "2026-09-01"
          description "Discussion and member types use their current names."
          renamed_type from: :discussions, to: :topics
          renamed_type from: :members, to: :users
        end
        .new(__FILE__)
    end
    let(:query) { super().merge("fields" => { "discussions" => "author", "members" => "groups" }) }

    it "composes type and relationship renames at each segment" do
      expect(primary_resource).to include(
        "type" => "discussions",
        "relationships" => {
          "author" =>
            a_hash_including("data" => { "type" => "members", "id" => newest.user_id.to_s }),
        },
      )
    end
  end
end
