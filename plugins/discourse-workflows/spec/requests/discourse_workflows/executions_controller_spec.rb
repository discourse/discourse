# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExecutionsController do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  before { sign_in(admin) }

  def workflow_snapshot_data(name)
    { "name" => name, "nodes" => [], "connections" => {} }
  end

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/executions.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/executions" do
    fab!(:published_workflow) do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:manual" }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    end

    it "returns a pending execution" do
      post "/admin/plugins/discourse-workflows/executions.json",
           params: {
             workflow_id: published_workflow.id,
             trigger_node_id: "trigger-1",
           }

      expect(response).to have_http_status(:created)
      execution = DiscourseWorkflows::Execution.find(response.parsed_body.dig("execution", "id"))
      expect(response.parsed_body["execution"]).to include(
        "id" => execution.id,
        "workflow_id" => published_workflow.id,
      )
      expect(execution.status).to eq("pending")

      job_args = Jobs::DiscourseWorkflows::ExecuteManualWorkflow.jobs.last["args"].first
      expect(job_args).to include("execution_id" => execution.id, "user_id" => admin.id)
    end

    it "returns 404 when trigger node does not exist" do
      post "/admin/plugins/discourse-workflows/executions.json",
           params: {
             workflow_id: workflow.id,
             trigger_node_id: "nonexistent",
           }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/executions" do
    it "returns executions" do
      execution = Fabricate(:discourse_workflows_completed_execution, workflow: workflow)

      get "/admin/plugins/discourse-workflows/executions.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["executions"].length).to eq(1)
      expect(json["executions"][0]).to include(
        "id" => execution.id,
        "workflow_name" => workflow.name,
      )
    end

    it "returns the stored snapshot workflow name" do
      execution = Fabricate(:discourse_workflows_completed_execution, workflow: workflow)
      Fabricate(
        :discourse_workflows_execution_data,
        execution: execution,
        workflow_data: workflow_snapshot_data("Original workflow"),
      )
      workflow.update!(name: "Renamed workflow")

      get "/admin/plugins/discourse-workflows/executions.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["executions"][0]).to include(
        "id" => execution.id,
        "workflow_name" => "Original workflow",
      )
    end

    it "paginates with cursor param" do
      execution_1 = Fabricate(:discourse_workflows_execution, workflow: workflow)
      execution_2 = Fabricate(:discourse_workflows_execution, workflow: workflow)

      get "/admin/plugins/discourse-workflows/executions.json",
          params: {
            cursor: execution_2.id,
            limit: 10,
          }

      json = response.parsed_body
      expect(json["executions"].length).to eq(1)
      expect(json["executions"][0]["id"]).to eq(execution_1.id)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/workflows/:workflow_id/executions" do
    it "returns executions for the workflow" do
      execution = Fabricate(:discourse_workflows_completed_execution, workflow: workflow)
      Fabricate(:discourse_workflows_completed_execution)

      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/executions.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["executions"].length).to eq(1)
      expect(json["executions"][0]["id"]).to eq(execution.id)
    end

    it "returns the stored snapshot workflow name" do
      execution = Fabricate(:discourse_workflows_completed_execution, workflow: workflow)
      Fabricate(:discourse_workflows_completed_execution)
      Fabricate(
        :discourse_workflows_execution_data,
        execution: execution,
        workflow_data: workflow_snapshot_data("Original workflow"),
      )
      workflow.update!(name: "Renamed workflow")

      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/executions.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["executions"][0]).to include(
        "id" => execution.id,
        "workflow_name" => "Original workflow",
      )
    end

    it "returns empty when no executions exist" do
      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/executions.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["executions"]).to be_empty
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/executions" do
    fab!(:execution) { Fabricate(:discourse_workflows_completed_execution, workflow: workflow) }

    it "deletes executions" do
      delete "/admin/plugins/discourse-workflows/executions.json", params: { ids: [execution.id] }

      expect(response).to have_http_status(:no_content)
      expect(DiscourseWorkflows::Execution.exists?(execution.id)).to be(false)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/executions/:id" do
    fab!(:execution) { Fabricate(:discourse_workflows_completed_execution, workflow: workflow) }

    before { Fabricate(:discourse_workflows_execution_data_with_steps, execution: execution) }

    it "returns the execution with steps" do
      get "/admin/plugins/discourse-workflows/executions/#{execution.id}.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["execution"]["id"]).to eq(execution.id)
      expect(json["execution"]["workflow_name"]).to eq(workflow.name)
      expect(json["execution"]["steps"].length).to eq(1)
    end

    it "returns caller workflow data for child executions" do
      target_workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
      child_execution =
        Fabricate(:discourse_workflows_completed_execution, workflow: target_workflow)
      Fabricate(:discourse_workflows_execution_data_with_steps, execution: child_execution)

      execution.execution_data.update!(
        workflow_data: {
          "name" => "Parent workflow",
          "nodes" => [
            { "id" => "call-1", "name" => "Call child workflow", "type" => "action:workflow_call" },
          ],
          "connections" => {
          },
        },
      )
      DiscourseWorkflows::WorkflowCallRun.create!(
        parent_execution: execution,
        parent_node_id: "call-1",
        parent_resume_token: SecureRandom.hex(16),
        target_workflow: target_workflow,
        target_workflow_version_id: target_workflow.version_id,
        child_execution: child_execution,
        user: admin,
        trigger_data: {
        },
        status: :success,
      )

      get "/admin/plugins/discourse-workflows/executions/#{child_execution.id}.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("execution", "workflow_call_caller")).to include(
        "workflow_id" => workflow.id,
        "workflow_name" => "Parent workflow",
        "execution_id" => execution.id,
        "execution_url" =>
          DiscourseWorkflows::Execution.admin_execution_url(workflow.id, execution.id),
        "node_id" => "call-1",
        "node_name" => "Call child workflow",
        "node_type" => "action:workflow_call",
      )
    end

    it "returns the stored snapshot workflow name" do
      execution.execution_data.update!(workflow_data: workflow_snapshot_data("Original workflow"))
      workflow.update!(name: "Renamed workflow")

      get "/admin/plugins/discourse-workflows/executions/#{execution.id}.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["execution"]).to include(
        "id" => execution.id,
        "workflow_name" => "Original workflow",
      )
    end

    it "returns 404 when execution does not exist" do
      get "/admin/plugins/discourse-workflows/executions/-1.json"
      expect(response).to have_http_status(:not_found)
    end
  end
end
