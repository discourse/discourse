# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExecutionsController do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  before do
    SiteSetting.discourse_workflows_enabled = true
    sign_in(admin)
  end

  describe "POST /admin/plugins/discourse-workflows/executions" do
    before do
      DiscourseWorkflows::Registry.reset!
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual::V1)
    end

    after { DiscourseWorkflows::Registry.reset! }

    it "creates an execution" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true)
      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:manual",
          name: "Manual Trigger",
        )

      post "/admin/plugins/discourse-workflows/executions.json",
           params: {
             trigger_node_id: trigger_node.id,
           }

      expect(response.status).to eq(200)
    end

    it "returns 404 when trigger node does not exist" do
      post "/admin/plugins/discourse-workflows/executions.json", params: { trigger_node_id: -1 }
      expect(response.status).to eq(404)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/executions" do
    it "returns executions" do
      execution =
        DiscourseWorkflows::Execution.create!(
          workflow: workflow,
          status: :success,
          started_at: 1.hour.ago,
          finished_at: Time.current,
          trigger_data: {
          },
        )

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
      DiscourseWorkflows::Execution.create!(workflow: workflow, status: :pending, trigger_data: {})

      get "/admin/plugins/discourse-workflows/executions.json"

      json = response.parsed_body
      expect(json["meta"]["total_rows_executions"]).to eq(1)
    end

    it "paginates with cursor param" do
      execution_1 =
        DiscourseWorkflows::Execution.create!(
          workflow: workflow,
          status: :pending,
          trigger_data: {
          },
        )
      execution_2 =
        DiscourseWorkflows::Execution.create!(
          workflow: workflow,
          status: :pending,
          trigger_data: {
          },
        )

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
    fab!(:execution) do
      DiscourseWorkflows::Execution.create!(workflow: workflow, status: :success, trigger_data: {})
    end

    it "deletes executions" do
      delete "/admin/plugins/discourse-workflows/executions.json", params: { ids: [execution.id] }

      expect(response.status).to eq(200)
      expect(response.parsed_body["deleted_count"]).to eq(1)
      expect(DiscourseWorkflows::Execution.exists?(execution.id)).to eq(false)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/executions/:id" do
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

    fab!(:node) do
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:manual",
        name: "Manual Trigger",
      )
    end

    fab!(:step) do
      DiscourseWorkflows::ExecutionStep.create!(
        execution: execution,
        node: node,
        node_name: node.name,
        node_type: node.type,
        position: 0,
        status: :success,
        input: {
        },
        output: {
        },
        started_at: 1.hour.ago,
        finished_at: Time.current,
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
