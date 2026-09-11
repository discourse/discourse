# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowSettingFieldsController do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404 for create" do
      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields.json",
           params: {
             key: "priority",
             label: "Priority",
             field_type: "string",
           }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/workflows/:workflow_id/setting-fields" do
    it "creates a setting field and returns the workflow's updated publish state" do
      workflow.update_columns(active_version_id: workflow.version_id)

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields.json",
           params: {
             key: "priority",
             label: "Priority",
             field_type: "string",
           }

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["workflow_setting_field"]).to include("key" => "priority", "label" => "Priority")
      expect(json["workflow"]["has_unpublished_changes"]).to be(true)
    end

    it "returns 400 when key is missing" do
      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields.json",
           params: {
             label: "Priority",
             field_type: "string",
           }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 404 when the workflow does not exist" do
      post "/admin/plugins/discourse-workflows/workflows/-1/setting-fields.json",
           params: {
             key: "priority",
             label: "Priority",
             field_type: "string",
           }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/workflows/:workflow_id/setting-fields/:setting_field_id" do
    fab!(:setting_field) do
      Fabricate(
        :discourse_workflows_workflow_setting_field,
        workflow:,
        key: "priority",
        label: "Priority",
        field_type: "string",
      )
    end

    it "updates a setting field and returns the workflow's updated publish state" do
      workflow.update_columns(active_version_id: workflow.version_id)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields/#{setting_field.id}.json",
          params: {
            key: "priority",
            label: "Updated label",
            field_type: "string",
          }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow_setting_field"]["label"]).to eq("Updated label")
      expect(response.parsed_body["workflow"]["has_unpublished_changes"]).to be(true)
    end

    it "returns 404 when the setting field does not exist" do
      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields/-1.json",
          params: {
            key: "priority",
            label: "Priority",
            field_type: "string",
          }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/workflows/:workflow_id/setting-fields/:setting_field_id" do
    fab!(:setting_field) do
      Fabricate(
        :discourse_workflows_workflow_setting_field,
        workflow:,
        key: "priority",
        label: "Priority",
        field_type: "string",
      )
    end

    it "deletes a setting field and returns the workflow's updated publish state" do
      workflow.update_columns(active_version_id: workflow.version_id)

      delete "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields/#{setting_field.id}.json"

      expect(response).to have_http_status(:ok)
      expect(DiscourseWorkflows::WorkflowSettingField.exists?(setting_field.id)).to be(false)
      expect(response.parsed_body["workflow"]["has_unpublished_changes"]).to be(true)
    end

    it "returns 404 when the setting field does not exist" do
      delete "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields/-1.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/workflows/:workflow_id/setting-fields/:setting_field_id/value" do
    fab!(:setting_field) do
      Fabricate(
        :discourse_workflows_workflow_setting_field,
        workflow:,
        key: "priority",
        label: "Priority",
        field_type: "enum",
        type_options: {
          "choices" => %w[low medium high],
        },
      )
    end

    it "updates the field's value" do
      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields/#{setting_field.id}/value.json",
          params: {
            value: "high",
          }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["workflow_setting_field"]["value"]).to eq("high")
      expect(json["workflow"]).to include(
        "has_unpublished_changes" => false,
        "active_version_id" => nil,
      )
    end

    it "auto-publishes the value when the workflow is published with a clean draft" do
      workflow.update!(active_version_id: workflow.version_id)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields/#{setting_field.id}/value.json",
          params: {
            value: "high",
          }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["workflow"]["has_unpublished_changes"]).to eq(false)
      expect(json["workflow"]["active_version_id"]).to eq(json["workflow"]["version_id"])
    end

    it "returns 422 when the value is invalid for the field's type" do
      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields/#{setting_field.id}/value.json",
          params: {
            value: "extreme",
          }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 when the setting field does not exist" do
      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields/-1/value.json",
          params: {
            value: "high",
          }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/workflows/:workflow_id/setting-fields/import" do
    it "creates every imported field in a single new version" do
      expect {
        post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields/import.json",
             params: {
               setting_fields: [
                 { key: "priority", label: "Priority", field_type: "string" },
                 {
                   key: "notify_categories",
                   label: "Notify categories",
                   field_type: "category_list",
                 },
               ],
             }
      }.to change { workflow.reload.version_counter }.by(1)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["imported_count"]).to eq(2)
      expect(json["skipped_keys"]).to eq([])
      expect(workflow.setting_fields.pluck(:key)).to contain_exactly(
        "priority",
        "notify_categories",
      )
    end

    it "skips fields whose key already exists on the workflow" do
      Fabricate(
        :discourse_workflows_workflow_setting_field,
        workflow:,
        key: "priority",
        label: "Existing priority",
        field_type: "enum",
        type_options: {
          "choices" => %w[low high],
        },
      )

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/setting-fields/import.json",
           params: {
             setting_fields: [
               { key: "priority", label: "Imported priority", field_type: "string" },
             ],
           }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["imported_count"]).to eq(0)
      expect(json["skipped_keys"]).to eq(["priority"])
      expect(workflow.setting_fields.find_by(key: "priority").label).to eq("Existing priority")
    end

    it "returns 404 when the workflow does not exist" do
      post "/admin/plugins/discourse-workflows/workflows/-1/setting-fields/import.json",
           params: {
             setting_fields: [{ key: "priority", label: "Priority", field_type: "string" }],
           }
      expect(response).to have_http_status(:not_found)
    end
  end
end
