# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowExecutionsController do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/executions.json"
      expect(response.status).to eq(404)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/workflows/:workflow_id/executions" do
    fab!(:execution) { Fabricate(:discourse_workflows_completed_execution, workflow: workflow) }

    it "returns executions for the workflow" do
      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/executions.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["executions"].length).to eq(1)
      expect(json["executions"][0]["id"]).to eq(execution.id)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/workflows/:workflow_id/executions with no data" do
    it "returns empty when no executions exist" do
      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/executions.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["executions"]).to be_empty
      expect(json["meta"]["total_rows_executions"]).to eq(0)
    end
  end
end
