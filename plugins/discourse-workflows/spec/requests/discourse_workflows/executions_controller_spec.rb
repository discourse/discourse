# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExecutionsController do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/executions.json"
      expect(response.status).to eq(404)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/executions" do
    fab!(:enabled_workflow) do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:manual" }
      Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true, **graph)
    end

    it "creates an execution" do
      post "/admin/plugins/discourse-workflows/executions.json",
           params: {
             workflow_id: enabled_workflow.id,
             trigger_node_id: "trigger-1",
           }

      expect(response.status).to eq(200)
    end

    it "returns 404 when trigger node does not exist" do
      post "/admin/plugins/discourse-workflows/executions.json",
           params: {
             workflow_id: workflow.id,
             trigger_node_id: "nonexistent",
           }
      expect(response.status).to eq(404)
    end

    it "passes current user to execution" do
      DiscourseWorkflows::Workflow::Execute
        .expects(:call)
        .with { |kwargs| kwargs.dig(:params, :user_id) == admin.id }
        .returns(Service::Base::Context.build)

      post "/admin/plugins/discourse-workflows/executions.json",
           params: {
             workflow_id: enabled_workflow.id,
             trigger_node_id: "trigger-1",
           }
    end
  end

  describe "GET /admin/plugins/discourse-workflows/executions" do
    it "returns executions" do
      execution = Fabricate(:discourse_workflows_completed_execution, workflow: workflow)

      get "/admin/plugins/discourse-workflows/executions.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["executions"].length).to eq(1)
      expect(json["executions"][0]).to include(
        "id" => execution.id,
        "workflow_name" => workflow.name,
      )
    end

    it "returns meta with total rows" do
      Fabricate(:discourse_workflows_execution, workflow: workflow)

      get "/admin/plugins/discourse-workflows/executions.json"

      json = response.parsed_body
      expect(json["meta"]["total_rows_executions"]).to eq(1)
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

  describe "DELETE /admin/plugins/discourse-workflows/executions" do
    fab!(:execution) { Fabricate(:discourse_workflows_completed_execution, workflow: workflow) }

    it "deletes executions" do
      delete "/admin/plugins/discourse-workflows/executions.json", params: { ids: [execution.id] }

      expect(response.status).to eq(200)
      expect(response.parsed_body["deleted_count"]).to eq(1)
      expect(DiscourseWorkflows::Execution.exists?(execution.id)).to be(false)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/executions/:id" do
    fab!(:execution) { Fabricate(:discourse_workflows_completed_execution, workflow: workflow) }

    before do
      Fabricate(
        :discourse_workflows_execution_data_with_steps,
        execution: execution,
        workflow_data: {
        },
      )
    end

    it "returns the execution with steps" do
      get "/admin/plugins/discourse-workflows/executions/#{execution.id}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["execution"]["id"]).to eq(execution.id)
      expect(json["execution"]["steps"].length).to eq(1)
    end

    it "returns 404 when execution does not exist" do
      get "/admin/plugins/discourse-workflows/executions/-1.json"
      expect(response.status).to eq(404)
    end
  end
end
