# frozen_string_literal: true

module JsonApiKitPatchSpec
  class GroupResource < JsonApiKit::Resource
    model Group
    type :groups

    attribute :name, :string, writable: true
    attribute :full_name, :string, writable: true
    attribute :bio_raw, :string, writable: true
  end

  class UpdateGroup
    include Service::Base

    model :group
    policy :can_update_group

    params(from_resource: GroupResource, default_values_from: :group) do
      validates :name, presence: true
    end

    step :update_group

    private

    def fetch_group(params:)
      Group.find_by(id: params.group_id)
    end

    def can_update_group(guardian:)
      guardian.is_admin?
    end

    def update_group(group:, params:)
      group.update!(**params)
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
        on_model_not_found(:group) { raise Discourse::NotFound }
      end
    end
  end

  class RenameGroups < JsonApiKit::VersionChange
    version "2026-09-01"
    description "Teams become groups with names and biographies."

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

    before do
      freeze_time(Date.new(2026, 9, 2))
      allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
      allow(JsonApiKitPatchSpec::GroupResource).to receive(:scope_for).and_call_original
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
      expect(JsonApiKitPatchSpec::GroupResource).not_to have_received(:scope_for)
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
          expect(JsonApiKitPatchSpec::GroupResource).not_to have_received(:scope_for)
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
          expect(JsonApiKitPatchSpec::GroupResource).to have_received(:scope_for).once
        end

        context "when the supplied value is null" do
          let(:attributes) { super().merge("intro" => nil) }

          it "preserves null during completion", :aggregate_failures do
            expect { update_group }.to change { group.reload.bio_raw }.to("\nRetained details")
            expect(response).to have_http_status(:ok)
            expect(JsonApiKitPatchSpec::GroupResource).to have_received(:scope_for).once
          end
        end

        context "when the target is outside the resource scope" do
          before do
            allow(JsonApiKitPatchSpec::GroupResource).to receive(:scope_for).and_return(Group.none)
          end

          it "refuses to complete the conversion", :aggregate_failures do
            expect { update_group }.not_to change { group.reload.attributes }
            expect(response).to have_http_status(:not_found)
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

    context "when the target does not exist" do
      let(:target_id) { Group.maximum(:id).next.to_s }

      it "returns not found", :aggregate_failures do
        expect { update_group }.not_to change { group.reload.attributes }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the actor cannot update groups" do
      fab!(:user)

      let(:actor) { user }

      it "preserves the service policy", :aggregate_failures do
        expect { update_group }.not_to change { group.reload.attributes }
        expect(response).to have_http_status(:forbidden)
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("status" => "403", "title" => "Forbidden"),
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
