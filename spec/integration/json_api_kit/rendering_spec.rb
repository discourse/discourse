# frozen_string_literal: true

module JsonApiKitRenderSpec
  class UserResource < JsonApiKit::Resource
    model User
    type :users

    attribute :username
  end

  class GroupResource < JsonApiKit::Resource
    model Group
    type :groups

    scope { Group.none }

    attribute :name
    attribute :public_admission

    has_many :users, resource: UserResource
  end

  class GroupsController < JsonApiKit::BaseController
    resource GroupResource

    def index = render_document(records)

    def created = render_document(records.to_a, status: :created)

    private

    def records
      Group.where(name: %w[render_middle render_zeta]).order(name: :desc)
    end
  end

  class ErrorsController < JsonApiKit::BaseController
    def index
      render_document(JsonApiKit::Document::Errors.new(JsonApiKit::BadRequest.new("Invalid input")))
    end
  end
end

RSpec.describe "Rendering supplied JSON:API documents", type: :request do
  subject(:render_collection) do
    get path, params: query, headers: { "HTTP_API_VERSION" => JsonApiKit::Timeline.current.to_s }
  end

  fab!(:member, :user)
  fab!(:second_group) { Fabricate(:group, name: "render_middle") }
  fab!(:last_group) { Fabricate(:group, name: "render_zeta", users: [member]) }

  let(:path) { "/api/rendered-groups" }
  let(:query) { {} }
  let(:parsed_body) { JSON.parse(response.body) }
  let(:rendered_ids) { parsed_body.fetch("data").map { it.fetch("id") } }

  before do
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/rendered-groups" => "json_api_kit_render_spec/groups#index"
      get "/api/rendered-groups/created" => "json_api_kit_render_spec/groups#created"
      get "/api/rendered-errors" => "json_api_kit_render_spec/errors#index"
    end
    Rails.application.routes.disable_clear_and_finalize = false
  end

  after { Rails.application.reload_routes! }

  context "when the query selects fields and included resources" do
    let(:query) { { fields: { groups: "name,users" }, include: "users" } }

    it "applies the requested representation", :aggregate_failures do
      render_collection

      expect(response).to have_http_status(:ok)
      expect(parsed_body.fetch("data").map { it.fetch("attributes") }).to eq(
        [{ "name" => last_group.name }, { "name" => second_group.name }],
      )
      expect(parsed_body.fetch("included")).to contain_exactly(
        a_hash_including(
          "type" => "users",
          "id" => member.id.to_s,
          "attributes" => {
            "username" => member.username,
          },
        ),
      )
    end
  end

  context "when the action supplies a created collection" do
    let(:path) { "#{super()}/created" }

    it "renders the collection without an individual location", :aggregate_failures do
      render_collection

      expect(response).to have_http_status(:created)
      expect(rendered_ids).to eq([last_group.id.to_s, second_group.id.to_s])
      expect(response.headers).not_to have_key("Location")
    end
  end

  context "when the action supplies an error document without a resource" do
    let(:path) { "/api/rendered-errors" }
    let(:query) { { unsupported: "value" } }

    it "renders the prepared errors", :aggregate_failures do
      render_collection

      expect(response).to have_http_status(:bad_request)
      expect(parsed_body.fetch("errors")).to contain_exactly(
        "status" => "400",
        "title" => "Bad request",
        "detail" => "Invalid input",
      )
    end
  end
end
