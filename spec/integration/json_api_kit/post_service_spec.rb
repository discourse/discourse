# frozen_string_literal: true

module JsonApiKitPostSpec
  class UserResource < JsonApiKit::Resource
    model User
    type :users

    attribute :username
    attribute :email, readable: ->(guardian) { guardian.can_see_emails? }
  end

  class GroupResource < JsonApiKit::Resource
    model Group
    type :groups

    scope { Group.none }

    attribute :name, :string, writable: true
    attribute :public_admission, :boolean, writable: true
    attribute :full_name, :string, writable: true
    attribute :flair_icon

    has_many :users, resource: UserResource
  end

  class CreateGroup
    include Service::Base

    params(from_resource: GroupResource, only: %i[name public_admission]) do
      attribute :bio_raw, :string

      validates :name, presence: true
    end

    policy :can_create_group
    model :group, :create_group

    private

    def can_create_group(guardian:)
      guardian.is_admin?
    end

    def create_group(params:, guardian:)
      Group.create(**params, users: [guardian.user])
    end
  end

  class GroupsController < JsonApiKit::BaseController
    resource GroupResource

    def create
      CreateGroup.call(service_params) do
        on_success { |group:| render_document(group, status: :created) }
        on_failed_contract { |contract| render_validation_errors(contract.errors) }
        on_failed_policy(:can_create_group) { raise Discourse::InvalidAccess }
        on_model_errors(:group) { |group| render_validation_errors(group.errors) }
      end
    end
  end

  class RenameGroups < JsonApiKit::VersionChange
    version "2026-09-01"
    description "Teams become groups with names."

    renamed_type from: :teams, to: :groups

    resource :groups do
      renamed_attribute from: :label,
                        to: :name,
                        up: ->(label) { label&.strip },
                        down: ->(name) { name }
      merged_attributes from: %i[intro details],
                        to: :bio_raw,
                        up: ->(intro, details) { [intro, details].join("\n") },
                        down: ->(biography) { biography.split("\n", 2) }
    end
  end
end

RSpec.describe JsonApiKitPostSpec::GroupsController, type: :request do
  describe "#create" do
    subject(:create_group) do
      post path,
           params: document.to_json,
           headers: {
             "HTTP_API_VERSION" => version,
             "CONTENT_TYPE" => JsonApiKit::MediaType::JSON_API,
           }
    end

    fab!(:admin)

    let(:actor) { admin }
    let(:path) { "/api/groups" }
    let(:version) { "2026-09-01" }
    let(:type) { "groups" }
    let(:document) { { "data" => primary } }
    let(:primary) { { "type" => type, "attributes" => attributes } }
    let(:attributes) { { "name" => "api_group", "publicAdmission" => "false" } }
    let(:version_changes) do
      JsonApiKit::VersionChanges.new([JsonApiKitPostSpec::RenameGroups.new(__FILE__)])
    end
    let(:parsed_body) { JSON.parse(response.body) }
    let(:group) { Group.find_by!(name: "api_group") }
    let(:expected_attributes) do
      { "name" => "api_group", "publicAdmission" => false, "fullName" => nil, "flairIcon" => nil }
    end
    let(:location) { "http://test.localhost/api/groups/#{group.id}" }
    let(:pointer) { "/data/attributes/name" }

    before do
      freeze_time(Date.new(2026, 9, 2))
      allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
      sign_in(actor)
      Rails.application.routes.disable_clear_and_finalize = true
      Rails.application.routes.draw { post "/api/groups" => "json_api_kit_post_spec/groups#create" }
      Rails.application.routes.disable_clear_and_finalize = false
    end

    after { Rails.application.reload_routes! }

    shared_examples "a created group" do
      it "creates the group from the submitted attributes", :aggregate_failures do
        expect { create_group }.to change(Group, :count).by(1)
        expect(group).to have_attributes(name: "api_group", public_admission: false)
      end

      it "returns the created representation", :aggregate_failures do
        create_group

        expect(response).to have_http_status(:created)
        expect(JsonApiKit::MediaType.new(response.media_type)).to be_json_api
        expect(response.headers["Location"]).to eq(location)
        expect(parsed_body.fetch("data")).to include(
          "type" => type,
          "id" => group.id.to_s,
          "attributes" => expected_attributes,
          "links" => {
            "self" => location,
          },
        )
      end
    end

    shared_examples "a contract refusal" do
      it "reports the submitted location without creating a group", :aggregate_failures do
        expect { create_group }.not_to change(Group, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("status" => "422", "source" => { "pointer" => pointer }),
        )
      end
    end

    it_behaves_like "a created group"

    context "when the client uses an older version" do
      let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
      let(:type) { "teams" }
      let(:attributes) { super().except("name").merge("label" => " api_group ") }
      let(:expected_attributes) { super().except("name").merge("label" => "api_group") }

      it_behaves_like "a created group"

      context "when the converted name is invalid" do
        let(:attributes) { super().merge("label" => " ") }
        let(:pointer) { "/data/attributes/label" }

        it_behaves_like "a contract refusal"
      end

      context "when the model rejects a merged value" do
        let(:attributes) { super().merge("intro" => "A" * 1500, "details" => "B" * 1500) }

        it "reports the submitted attributes object", :aggregate_failures do
          expect { create_group }.not_to change(Group, :count)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_body.fetch("errors")).to contain_exactly(
            a_hash_including("status" => "422", "source" => { "pointer" => "/data/attributes" }),
          )
        end
      end
    end

    context "when the contract declares an attribute absent from the resource" do
      let(:attributes) { super().merge("bioRaw" => "Created through the API") }

      it "supplies the attribute to the service" do
        expect { create_group }.to change { Group.find_by(name: "api_group")&.bio_raw }.to(
          attributes.fetch("bioRaw"),
        )
      end
    end

    context "when the contract omits submitted attributes" do
      let(:attributes) do
        super().merge("fullName" => "Ignored name", "flairIcon" => "star", "unknownField" => true)
      end

      it "ignores attributes outside the contract", :aggregate_failures do
        create_group

        expect(response).to have_http_status(:created)
        expect(group).to have_attributes(full_name: nil, flair_icon: nil)
      end
    end

    context "when the query selects response fields" do
      let(:path) { "#{super()}?fields[groups]=name" }
      let(:attributes) { super().merge("publicAdmission" => "true") }

      it "applies the fieldset to the response", :aggregate_failures do
        create_group

        expect(response).to have_http_status(:created)
        expect(group).to be_public_admission
        expect(parsed_body.dig("data", "attributes")).to eq("name" => "api_group")
      end
    end

    context "when the query includes related users" do
      let(:path) { "#{super()}?include=users" }

      it "renders the created group's users", :aggregate_failures do
        create_group

        expect(response).to have_http_status(:created)
        expect(parsed_body.fetch("included")).to contain_exactly(
          a_hash_including(
            "type" => "users",
            "id" => actor.id.to_s,
            "attributes" => {
              "username" => actor.username,
              "email" => actor.email,
            },
          ),
        )
        expect(parsed_body.dig("data", "relationships", "users", "data")).to contain_exactly(
          "type" => "users",
          "id" => actor.id.to_s,
        )
      end
    end

    context "when the model rejects the name" do
      let(:attributes) { super().merge("name" => "invalid group name") }

      it "reports the submitted attribute", :aggregate_failures do
        expect { create_group }.not_to change(Group, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("status" => "422", "source" => { "pointer" => pointer }),
        )
      end
    end

    context "when the name is null" do
      let(:attributes) { super().merge("name" => nil) }

      it_behaves_like "a contract refusal"
    end

    context "when the name is omitted" do
      let(:attributes) { super().except("name") }
      let(:pointer) { "/data/attributes" }

      it_behaves_like "a contract refusal"
    end

    context "when attributes are omitted" do
      let(:primary) { super().except("attributes") }
      let(:pointer) { "/data" }

      it_behaves_like "a contract refusal"
    end

    context "when the attributes object is malformed" do
      let(:attributes) { [] }

      it "refuses the document before creating a group", :aggregate_failures do
        expect { create_group }.not_to change(Group, :count)
        expect(response).to have_http_status(:bad_request)
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("source" => { "pointer" => "/data/attributes" }),
        )
      end
    end

    context "when the query supplies an unsupported parameter" do
      let(:path) { "#{super()}?sort=name" }

      it "refuses the query before creating a group", :aggregate_failures do
        expect { create_group }.not_to change(Group, :count)
        expect(response).to have_http_status(:bad_request)
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("source" => { "parameter" => "sort" }),
        )
      end
    end

    context "when the actor cannot create groups" do
      fab!(:user)

      let(:actor) { user }

      it "preserves the service policy", :aggregate_failures do
        expect { create_group }.not_to change(Group, :count)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
