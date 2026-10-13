# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowVariablesController do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404 for create" do
      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables.json",
           params: {
             key: "priority",
             variable_type: "string",
           }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/workflows/:workflow_id/variables" do
    it "creates a variable and returns the workflow's updated publish state" do
      workflow.update_columns(active_version_id: workflow.version_id)

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables.json",
           params: {
             key: "priority",
             variable_type: "string",
           }

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["variable"]).to include("key" => "priority", "label" => "Priority")
      expect(json["workflow"]["has_unpublished_changes"]).to be(true)
    end

    it "returns 400 when key is missing" do
      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables.json",
           params: {
             variable_type: "string",
           }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 404 when the workflow does not exist" do
      post "/admin/plugins/discourse-workflows/workflows/-1/variables.json",
           params: {
             key: "priority",
             variable_type: "string",
           }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/workflows/:workflow_id/variables/:variable_id" do
    fab!(:variable) do
      Fabricate(
        :discourse_workflows_workflow_variable,
        workflow:,
        key: "priority",
        variable_type: "string",
      )
    end

    it "updates a variable and returns the workflow's updated publish state" do
      workflow.update_columns(active_version_id: workflow.version_id)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/#{variable.id}.json",
          params: {
            key: "priority_level",
            variable_type: "string",
          }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["variable"]["key"]).to eq("priority_level")
      expect(response.parsed_body["workflow"]["has_unpublished_changes"]).to be(true)
    end

    it "returns 404 when the variable does not exist" do
      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/-1.json",
          params: {
            key: "priority",
            variable_type: "string",
          }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the variable is actually a global variable" do
      global_variable = Fabricate(:discourse_workflows_variable, key: "global_one")

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/#{global_variable.id}.json",
          params: {
            key: "priority",
            variable_type: "string",
          }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/workflows/:workflow_id/variables/:variable_id" do
    fab!(:variable) do
      Fabricate(
        :discourse_workflows_workflow_variable,
        workflow:,
        key: "priority",
        variable_type: "string",
      )
    end

    it "deletes a variable and returns the workflow's updated publish state" do
      workflow.update_columns(active_version_id: workflow.version_id)

      delete "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/#{variable.id}.json"

      expect(response).to have_http_status(:ok)
      expect(DiscourseWorkflows::Variable.exists?(variable.id)).to be(false)
      expect(response.parsed_body["workflow"]["has_unpublished_changes"]).to be(true)
    end

    it "returns 404 when the variable does not exist" do
      delete "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/-1.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/workflows/:workflow_id/variables/:variable_id/value" do
    fab!(:variable) do
      Fabricate(
        :discourse_workflows_workflow_variable,
        workflow:,
        key: "priority",
        variable_type: "enum",
        type_options: {
          "choices" => %w[low medium high],
        },
      )
    end

    it "updates the variable's value" do
      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/#{variable.id}/value.json",
          params: {
            value: "high",
          }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["variable"]["value"]).to eq("high")
      expect(json["workflow"]).to include(
        "has_unpublished_changes" => false,
        "active_version_id" => nil,
      )
    end

    it "auto-publishes the value when the workflow is published with a clean draft" do
      workflow.update!(active_version_id: workflow.version_id)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/#{variable.id}/value.json",
          params: {
            value: "high",
          }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["workflow"]["has_unpublished_changes"]).to eq(false)
      expect(json["workflow"]["active_version_id"]).to eq(json["workflow"]["version_id"])
    end

    it "returns 422 when the value is invalid for the variable's type" do
      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/#{variable.id}/value.json",
          params: {
            value: "extreme",
          }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 when the variable does not exist" do
      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/-1/value.json",
          params: {
            value: "high",
          }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/workflows/:workflow_id/variables/import" do
    it "creates every imported variable in a single new version" do
      expect {
        post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/import.json",
             params: {
               variables: [
                 { key: "priority", variable_type: "string" },
                 { key: "notify_categories", variable_type: "category_list" },
               ],
             }
      }.to change { workflow.reload.version_counter }.by(1)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["imported_count"]).to eq(2)
      expect(json["skipped_keys"]).to eq([])
      expect(workflow.variables.pluck(:key)).to contain_exactly("priority", "notify_categories")
    end

    it "skips variables whose key already exists on the workflow" do
      Fabricate(
        :discourse_workflows_workflow_variable,
        workflow:,
        key: "priority",
        variable_type: "enum",
        type_options: {
          "choices" => %w[low high],
        },
      )

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/import.json",
           params: {
             variables: [{ key: "priority", variable_type: "string" }],
           }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["imported_count"]).to eq(0)
      expect(json["skipped_keys"]).to eq(["priority"])
      expect(workflow.variables.find_by(key: "priority").variable_type).to eq("enum")
    end

    it "returns 404 when the workflow does not exist" do
      post "/admin/plugins/discourse-workflows/workflows/-1/variables/import.json",
           params: {
             variables: [{ key: "priority", variable_type: "string" }],
           }
      expect(response).to have_http_status(:not_found)
    end
  end
end
