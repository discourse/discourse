# frozen_string_literal: true

module JsonApiKitPatchSpec
  class UserResource < JsonApiKit::Resource
    model User
    type :users

    attribute :username
  end

  class GroupResource < JsonApiKit::Resource
    model Group
    type :groups

    attribute :name, :string, writable: true
    attribute :full_name, :string, writable: true
    attribute :bio_raw, :string, writable: true

    has_many :users, resource: UserResource, writable: true
    has_one :smtp_updated_by, resource: UserResource, writable: true
  end

  class UpdateGroup
    include Service::Base

    model :group
    policy :can_update_group

    params(from_resource: GroupResource, default_values_from: :group) do
      validates :name, presence: true
      validates :smtp_updated_by_id, numericality: { greater_than: 0 }, allow_nil: true
    end

    only_if(:users_provided?) do
      model :users, optional: true
      policy :can_assign_users
    end

    transaction do
      step :update_group
      only_if(:users_provided?) { step :replace_users }
      only_if(:smtp_updated_by_provided?) { step :replace_smtp_updated_by }
    end

    private

    def fetch_group(params:)
      Group.find_by(id: params.group_id)
    end

    def can_update_group(guardian:)
      guardian.is_admin?
    end

    def update_group(group:, params:)
      group.update!(**params.slice(:name, :full_name, :bio_raw))
    end

    def users_provided?(params:) = params.users_provided?

    def smtp_updated_by_provided?(params:) = params.smtp_updated_by_provided?

    def fetch_users(params:)
      User.find(params.user_ids)
    end

    def can_assign_users(users:)
      users.all?(&:human?)
    end

    def replace_users(group:, users:)
      group.update!(users:)
    end

    def replace_smtp_updated_by(group:, params:)
      group.update!(smtp_updated_by_id: params.smtp_updated_by_id)
    end
  end

  class GroupsController < JsonApiKit::BaseController
    resource GroupResource

    def update
      UpdateGroup.call(
        service_params.deep_merge(params: { group_id: request.path_parameters.fetch(:id) }),
      ) do
        on_success { |group:| render_document(group) }
        on_failed_contract { |contract| render_validation_errors(contract.errors) }
        on_failed_policy(:can_update_group) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_assign_users) { raise Discourse::InvalidAccess }
        on_model_not_found(:group) { raise Discourse::NotFound }
        on_model_not_found(:users) { raise Discourse::NotFound }
      end
    end
  end

  class RenameGroups < JsonApiKit::VersionChange
    version "2026-09-01"
    description "Teams become groups with names and biographies."

    renamed_type from: :teams, to: :groups
    renamed_type from: :people, to: :users

    resource :groups do
      renamed_relationship from: :members, to: :users
      renamed_relationship from: :editor, to: :smtp_updated_by
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

RSpec.describe JsonApiKitPatchSpec::GroupsController, type: :request do
  describe "#update" do
    subject(:update_group) do
      patch path,
            params: document.to_json,
            headers: {
              "HTTP_API_VERSION" => version,
              "CONTENT_TYPE" => JsonApiKit::MediaType::JSON_API,
            }
    end

    fab!(:admin)
    fab!(:group) do
      Fabricate(
        :group,
        name: "original_group",
        full_name: "Original full name",
        bio_raw: "Original intro\nRetained details",
      )
    end

    let(:actor) { admin }
    let(:target_id) { group.id.to_s }
    let(:path) { "/api/groups/#{target_id}" }
    let(:version) { "2026-09-01" }
    let(:type) { "groups" }
    let(:document) { { "data" => primary } }
    let(:primary) { { "type" => type, "id" => target_id, "attributes" => attributes } }
    let(:attributes) { { "name" => "updated_group" } }
    let(:version_changes) do
      JsonApiKit::VersionChanges.new([JsonApiKitPatchSpec::RenameGroups.new(__FILE__)])
    end
    let(:parsed_body) { JSON.parse(response.body) }
    let(:expected_attributes) do
      {
        "name" => "updated_group",
        "fullName" => "Original full name",
        "bioRaw" => "Original intro\nRetained details",
      }
    end
    let(:status) { :bad_request }
    let(:pointer) { "/data/id" }
    let(:read_scope) { ->(_guardian) { Group.all } }
    let(:resource_class) { JsonApiKitPatchSpec::GroupResource }

    before do
      freeze_time(Date.new(2026, 9, 2))
      allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
      allow(described_class).to receive(:declared_resource).and_return(resource_class)
      allow(resource_class).to receive(:scope_definition).and_return(read_scope)
      allow(read_scope).to receive(:call).and_call_original
      sign_in(actor)
      Rails.application.routes.disable_clear_and_finalize = true
      Rails.application.routes.draw do
        patch "/api/groups/:id" => "json_api_kit_patch_spec/groups#update"
      end
      Rails.application.routes.disable_clear_and_finalize = false
    end

    after { Rails.application.reload_routes! }

    shared_examples "an invalid identity" do
      it "refuses the identity before updating the group", :aggregate_failures do
        expect { update_group }.not_to change { group.reload.attributes }
        expect(response).to have_http_status(status)
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("source" => { "pointer" => pointer }),
        )
      end
    end

    it "updates the submitted attribute", :aggregate_failures do
      expect { update_group }.to change { group.reload.name }.to("updated_group")
      expect(response).to have_http_status(:ok)
      expect(JsonApiKit::MediaType.new(response.media_type)).to be_json_api
      expect(response.headers["Location"]).to be_nil
      expect(parsed_body.fetch("data")).to include(
        "type" => type,
        "id" => group.id.to_s,
        "attributes" => expected_attributes,
      )
      expect(read_scope).not_to have_received(:call)
    end

    context "when some attributes are omitted" do
      it "preserves omitted attributes", :aggregate_failures do
        expect { update_group }.not_to change { group.reload.full_name }
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the client supplies null" do
      let(:attributes) { super().merge("fullName" => nil) }

      it "clears the attribute", :aggregate_failures do
        expect { update_group }.to change { group.reload.full_name }.to(nil)
        expect(response).to have_http_status(:ok)
        expect(parsed_body.dig("data", "attributes", "fullName")).to be_nil
      end
    end

    context "when the attributes member is omitted" do
      let(:primary) { super().except("attributes") }

      it "preserves the stored attributes", :aggregate_failures do
        expect { update_group }.not_to change { group.reload.slice(:name, :full_name, :bio_raw) }
        expect(response).to have_http_status(:ok)
      end
    end

    context "when an attribute supplies another group ID" do
      fab!(:other_group, :group)

      let(:attributes) { super().merge("groupId" => other_group.id) }

      it "updates the route's target", :aggregate_failures do
        expect { update_group }.not_to change { other_group.reload.attributes }
        expect(group.reload.name).to eq("updated_group")
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the group has existing relationships" do
      fab!(:previous_user, :user)
      fab!(:replacement_user, :user)

      let(:primary) { super().merge("relationships" => relationships) }
      let(:relationships) do
        {
          "users" => {
            "data" => [identifier],
          },
          "smtpUpdatedBy" => {
            "data" => editor_identifier,
          },
        }
      end
      let(:identifier) { { "type" => "users", "id" => replacement_user.id.to_s } }
      let(:editor_identifier) { identifier.merge("id" => admin.id.to_s) }

      before { group.update!(users: [previous_user], smtp_updated_by: previous_user) }

      it "replaces both relationships", :aggregate_failures do
        update_group

        expect(response).to have_http_status(:ok)
        expect(group.reload.user_ids).to contain_exactly(replacement_user.id)
        expect(group.smtp_updated_by_id).to eq(admin.id)
      end

      context "when the client clears the relationships" do
        let(:relationships) do
          { "users" => { "data" => [] }, "smtpUpdatedBy" => { "data" => nil } }
        end

        it "clears both relationships", :aggregate_failures do
          update_group

          expect(response).to have_http_status(:ok)
          expect(group.reload.user_ids).to be_empty
          expect(group.smtp_updated_by_id).to be_nil
        end
      end

      context "when relationships are omitted" do
        let(:primary) { super().except("relationships") }

        it "preserves both relationships", :aggregate_failures do
          update_group

          expect(response).to have_http_status(:ok)
          expect(group.reload.user_ids).to contain_exactly(previous_user.id)
          expect(group.smtp_updated_by_id).to eq(previous_user.id)
        end
      end

      context "when only the to-many relationship is supplied" do
        let(:primary) { super().except("attributes") }
        let(:relationships) { super().except("smtpUpdatedBy") }

        it "updates only the supplied relationship", :aggregate_failures do
          expect { update_group }.not_to change { group.reload.name }

          expect(response).to have_http_status(:ok)
          expect(group.user_ids).to contain_exactly(replacement_user.id)
          expect(group.smtp_updated_by_id).to eq(previous_user.id)
        end
      end

      context "when a to-one identifier casts to nil" do
        let(:editor_identifier) { super().merge("id" => "") }

        it "rejects the identifier without changing the resource", :aggregate_failures do
          expect { update_group }.not_to change { group.reload.attributes }
          expect(group.user_ids).to contain_exactly(previous_user.id)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_body.fetch("errors")).to contain_exactly(
            a_hash_including(
              "status" => "422",
              "source" => {
                "pointer" => "/data/relationships/smtpUpdatedBy/data",
              },
            ),
          )
        end
      end

      context "when a to-many identifier casts to nil" do
        let(:relationships) do
          super().merge("users" => { "data" => [identifier, identifier.merge("id" => "")] })
        end

        it "reports the invalid identifier without changing the resource", :aggregate_failures do
          expect { update_group }.not_to change { group.reload.attributes }
          expect(group.user_ids).to contain_exactly(previous_user.id)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_body.fetch("errors")).to contain_exactly(
            a_hash_including(
              "status" => "422",
              "source" => {
                "pointer" => "/data/relationships/users/data/1/id",
              },
            ),
          )
        end
      end

      context "when the actor cannot update groups" do
        let(:actor) { previous_user }

        it "preserves the attributes and relationships", :aggregate_failures do
          expect { update_group }.not_to change { group.reload.attributes }

          expect(response).to have_http_status(:forbidden)
          expect(group.user_ids).to contain_exactly(previous_user.id)
          expect(parsed_body.fetch("errors")).to contain_exactly(
            a_hash_including("status" => "403", "title" => "Forbidden"),
          )
        end
      end

      context "when a related user is not permitted" do
        fab!(:bot)

        let(:relationships) do
          { "users" => { "data" => [{ "type" => "users", "id" => bot.id.to_s }] } }
        end

        it "preserves the attributes and relationships", :aggregate_failures do
          expect { update_group }.not_to change { group.reload.attributes }
          expect(response).to have_http_status(:forbidden)
          expect(group.user_ids).to contain_exactly(previous_user.id)
        end
      end

      context "when a related user does not exist" do
        let(:relationships) do
          { "users" => { "data" => [{ "type" => "users", "id" => User.maximum(:id).next.to_s }] } }
        end

        it "preserves the attributes and relationships", :aggregate_failures do
          expect { update_group }.not_to change { group.reload.attributes }
          expect(response).to have_http_status(:not_found)
          expect(group.user_ids).to contain_exactly(previous_user.id)
        end
      end

      context "when the client uses an older version" do
        let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
        let(:type) { "teams" }
        let(:attributes) { { "label" => "updated_group" } }
        let(:identifier) { super().merge("type" => "people") }
        let(:relationships) do
          { "members" => { "data" => [identifier] }, "editor" => { "data" => editor_identifier } }
        end

        it "resolves the relationship and identifier types", :aggregate_failures do
          update_group

          expect(response).to have_http_status(:ok)
          expect(group.reload.user_ids).to contain_exactly(replacement_user.id)
          expect(group.smtp_updated_by_id).to eq(admin.id)
        end

        context "when the client supplies the current relationship name" do
          let(:relationships) do
            super().except("members").merge("users" => { "data" => [identifier] })
          end

          it "rejects the name before updating the group", :aggregate_failures do
            expect { update_group }.not_to change { group.reload.attributes }
            expect(response).to have_http_status(:bad_request)
            expect(parsed_body.fetch("errors")).to contain_exactly(
              a_hash_including("source" => { "pointer" => "/data/relationships/users" }),
            )
          end
        end

        context "when the client supplies the current identifier type" do
          let(:relationships) do
            { "members" => { "data" => [identifier.merge("type" => "users")] } }
          end

          it "rejects the type before updating the group", :aggregate_failures do
            expect { update_group }.not_to change { group.reload.attributes }
            expect(response).to have_http_status(:conflict)
            expect(parsed_body.fetch("errors")).to contain_exactly(
              a_hash_including(
                "source" => {
                  "pointer" => "/data/relationships/members/data/0/type",
                },
              ),
            )
          end
        end

        context "when the contract rejects an identifier" do
          let(:editor_identifier) { super().merge("id" => "-1") }

          it "reports the original relationship", :aggregate_failures do
            expect { update_group }.not_to change { group.reload.attributes }
            expect(group.user_ids).to contain_exactly(previous_user.id)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(parsed_body.fetch("errors")).to contain_exactly(
              a_hash_including(
                "status" => "422",
                "source" => {
                  "pointer" => "/data/relationships/editor/data",
                },
              ),
            )
          end
        end
      end
    end

    context "when the client uses an older version" do
      let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
      let(:type) { "teams" }
      let(:attributes) { { "label" => " updated_group " } }
      let(:expected_attributes) do
        super().except("name", "bioRaw").merge(
          "label" => "updated_group",
          "intro" => "Original intro",
          "details" => "Retained details",
        )
      end

      it "uses the client's attribute names in both directions", :aggregate_failures do
        expect { update_group }.to change { group.reload.name }.to("updated_group")
        expect(response).to have_http_status(:ok)
        expect(parsed_body.fetch("data")).to include(
          "type" => type,
          "id" => group.id.to_s,
          "attributes" => expected_attributes,
        )
      end

      context "when the client supplies every merged attribute" do
        let(:attributes) { { "intro" => "Updated intro", "details" => "Updated details" } }

        it "converts the supplied values without loading existing values", :aggregate_failures do
          expect { update_group }.to change { group.reload.bio_raw }.to(
            "Updated intro\nUpdated details",
          )
          expect(response).to have_http_status(:ok)
          expect(read_scope).not_to have_received(:call)
        end
      end

      context "when the client supplies part of a merged attribute" do
        let(:attributes) { { "intro" => "Updated intro" } }

        it "completes the conversion with the stored value", :aggregate_failures do
          expect { update_group }.to change { group.reload.bio_raw }.to(
            "Updated intro\nRetained details",
          )
          expect(response).to have_http_status(:ok)
          expect(parsed_body.dig("data", "attributes")).to include(
            "intro" => "Updated intro",
            "details" => "Retained details",
          )
          expect(read_scope).to have_received(:call).once
        end

        context "when the supplied value is null" do
          let(:attributes) { super().merge("intro" => nil) }

          it "preserves null during completion", :aggregate_failures do
            expect { update_group }.to change { group.reload.bio_raw }.to("\nRetained details")
            expect(response).to have_http_status(:ok)
            expect(read_scope).to have_received(:call).once
          end
        end

        context "when the target is outside the resource scope" do
          let(:read_scope) { ->(_guardian) { Group.none } }

          it "refuses to complete the conversion", :aggregate_failures do
            expect { update_group }.not_to change { group.reload.attributes }
            expect(response).to have_http_status(:not_found)
            expect(JsonApiKit::MediaType.new(response.media_type)).to be_json_api
            expect(parsed_body.fetch("errors")).to contain_exactly(
              a_hash_including("status" => "404", "title" => "No such record"),
            )
          end
        end

        context "when the stored biography is unreadable" do
          let(:resource_class) do
            Class.new(JsonApiKit::Resource) do
              model Group
              type :groups

              attribute :name, :string, writable: true
              attribute :full_name, :string, writable: true
              attribute :bio_raw, :string, writable: true, readable: ->(_guardian) { false }
            end
          end

          before { allow(JsonApiKitPatchSpec::UpdateGroup).to receive(:call).and_call_original }

          it "refuses completion before calling the service", :aggregate_failures do
            expect { update_group }.not_to change { group.reload.attributes }
            expect(response).to have_http_status(:forbidden)
            expect(JsonApiKit::MediaType.new(response.media_type)).to be_json_api
            expect(parsed_body.fetch("errors")).to contain_exactly(
              a_hash_including("status" => "403", "title" => "Forbidden"),
            )
            expect(JsonApiKitPatchSpec::UpdateGroup).not_to have_received(:call)
          end

          context "when every merged attribute is supplied" do
            let(:attributes) { super().merge("details" => "Updated details") }

            it "updates without reading or exposing the stored biography", :aggregate_failures do
              expect { update_group }.to change { group.reload.bio_raw }.to(
                "Updated intro\nUpdated details",
              )
              expect(response).to have_http_status(:ok)
              expect(read_scope).not_to have_received(:call)
              expect(parsed_body.fetch("data").fetch("attributes")).not_to include(
                "intro",
                "details",
              )
            end
          end
        end
      end

      context "when the converted name is invalid" do
        let(:attributes) { { "label" => " " } }

        it "reports the submitted attribute", :aggregate_failures do
          expect { update_group }.not_to change { group.reload.attributes }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_body.fetch("errors")).to contain_exactly(
            a_hash_including(
              "status" => "422",
              "source" => {
                "pointer" => "/data/attributes/label",
              },
            ),
          )
        end
      end

      context "when the model rejects the converted name" do
        let(:attributes) { { "label" => "invalid group name" } }

        it "reports the original attribute in a JSON:API error", :aggregate_failures do
          expect { update_group }.not_to change { group.reload.attributes }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JsonApiKit::MediaType.new(response.media_type)).to be_json_api
          expect(parsed_body.fetch("errors")).to contain_exactly(
            a_hash_including(
              "status" => "422",
              "source" => {
                "pointer" => "/data/attributes/label",
              },
            ),
          )
        end
      end

      context "when the document identifies another target" do
        fab!(:other_group, :group)

        let(:primary) { super().merge("id" => other_group.id.to_s) }
        let(:attributes) { { "label" => [] } }

        it "refuses the identity before converting attributes", :aggregate_failures do
          expect { update_group }.not_to change {
            [group.reload.attributes, other_group.reload.attributes]
          }
          expect(response).to have_http_status(:conflict)
          expect(parsed_body.fetch("errors")).to contain_exactly(
            a_hash_including("source" => { "pointer" => "/data/id" }),
          )
        end
      end
    end

    context "when the ID is omitted" do
      let(:primary) { super().except("id") }
      let(:pointer) { "/data" }

      it_behaves_like "an invalid identity"
    end

    context "when the ID is a number" do
      let(:primary) { super().merge("id" => target_id.to_i) }

      it_behaves_like "an invalid identity"
    end

    context "when the ID differs before coercion" do
      let(:primary) { super().merge("id" => "0#{target_id}") }
      let(:status) { :conflict }

      it_behaves_like "an invalid identity"
    end

    context "when the type differs from the resource" do
      let(:primary) { super().merge("type" => "users") }
      let(:status) { :conflict }
      let(:pointer) { "/data/type" }

      it_behaves_like "an invalid identity"
    end

    context "when the model rejects the name" do
      let(:attributes) { { "name" => "invalid group name" } }

      it "reports the submitted attribute in a JSON:API error", :aggregate_failures do
        expect { update_group }.not_to change { group.reload.attributes }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JsonApiKit::MediaType.new(response.media_type)).to be_json_api
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("status" => "422", "source" => { "pointer" => "/data/attributes/name" }),
        )
      end
    end

    context "when the target does not exist" do
      let(:target_id) { Group.maximum(:id).next.to_s }

      it "returns not found", :aggregate_failures do
        expect { update_group }.not_to change { group.reload.attributes }
        expect(response).to have_http_status(:not_found)
        expect(JsonApiKit::MediaType.new(response.media_type)).to be_json_api
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("status" => "404", "title" => "No such record"),
        )
      end
    end

    context "when the query supplies an unsupported parameter" do
      let(:path) { "#{super()}?sort=name" }

      it "refuses the query before updating the group", :aggregate_failures do
        expect { update_group }.not_to change { group.reload.attributes }
        expect(response).to have_http_status(:bad_request)
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("source" => { "parameter" => "sort" }),
        )
      end
    end
  end
end
