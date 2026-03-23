# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowExecutionsController do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  before do
    SiteSetting.discourse_workflows_enabled = true
    sign_in(admin)
  end

  describe "GET /admin/plugins/discourse-workflows/workflows/:workflow_id/executions" do
    fab!(:execution) do
      DiscourseWorkflows::Execution.create!(
        workflow: workflow,
        status: :success,
        started_at: 1.hour.ago,
        finished_at: Time.current,
        trigger_data: {
        },
      )
    end

    it "returns executions for the workflow" do
      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/executions.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["executions"].length).to eq(1)
      expect(json["executions"][0]["id"]).to eq(execution.id)
    end
  end
end
