# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowsController do
  fab!(:admin)
  fab!(:tag)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    sign_in(admin)
  end

  describe "GET /admin/plugins/discourse-workflows/workflows" do
    it "returns workflows for authenticated users with access" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      get "/admin/plugins/discourse-workflows/workflows.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["workflows"].length).to eq(1)
      expect(json["workflows"][0]["name"]).to eq(workflow.name)
    end

    it "returns the latest execution status for each workflow" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      DiscourseWorkflows::Execution.create!(
        workflow: workflow,
        status: :error,
        created_at: 2.hours.ago,
      )
      DiscourseWorkflows::Execution.create!(
        workflow: workflow,
        status: :success,
        created_at: 1.hour.ago,
      )

      get "/admin/plugins/discourse-workflows/workflows.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["workflows"][0]["last_execution_status"]).to eq("success")
    end

    it "returns meta with total rows" do
      Fabricate(:discourse_workflows_workflow, created_by: admin)

      get "/admin/plugins/discourse-workflows/workflows.json"

      json = response.parsed_body
      expect(json["meta"]["total_rows_workflows"]).to eq(1)
    end

    it "returns load_more_workflows when there are more results" do
      stub_const(DiscourseWorkflows::Workflow::List, "DEFAULT_LIMIT", 1) do
        Fabricate(:discourse_workflows_workflow, created_by: admin, name: "First")
        Fabricate(:discourse_workflows_workflow, created_by: admin, name: "Second")

        get "/admin/plugins/discourse-workflows/workflows.json"

        json = response.parsed_body
        expect(json["workflows"].length).to eq(1)
        expect(json["meta"]["load_more_workflows"]).to be_present
      end
    end

    it "paginates with cursor param" do
      workflow_1 = Fabricate(:discourse_workflows_workflow, created_by: admin, name: "First")
      workflow_2 = Fabricate(:discourse_workflows_workflow, created_by: admin, name: "Second")

      get "/admin/plugins/discourse-workflows/workflows.json",
          params: {
            cursor: workflow_2.id,
            limit: 10,
          }

      json = response.parsed_body
      expect(json["workflows"].length).to eq(1)
      expect(json["workflows"][0]["id"]).to eq(workflow_1.id)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/workflows" do
    it "creates a workflow" do
      post "/admin/plugins/discourse-workflows/workflows.json",
           params: {
             name: "My Workflow",
             nodes: [
               { client_id: "t1", type: "trigger:topic_closed", name: "Topic Closed" },
               {
                 client_id: "a1",
                 type: "action:append_tags",
                 name: "Append Tags",
                 configuration: {
                   topic_id: "={{ trigger.topic_id }}",
                   tag_names: tag.name,
                 },
               },
             ],
             connections: [
               { source_client_id: "t1", target_client_id: "a1", source_output: "main" },
             ],
           }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["workflow"]["name"]).to eq("My Workflow")
      expect(json["workflow"]["nodes"].length).to eq(2)
      expect(json["workflow"]["connections"].length).to eq(1)
    end

    it "returns 400 when name is missing" do
      post "/admin/plugins/discourse-workflows/workflows.json", params: { nodes: [] }
      expect(response.status).to eq(400)
    end

    it "returns 422 when node validation fails" do
      DiscourseWorkflows::Registry.reset!
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Schedule::V1)

      post "/admin/plugins/discourse-workflows/workflows.json",
           params: {
             name: "Invalid Schedule",
             nodes: [
               {
                 client_id: "t1",
                 type: "trigger:schedule",
                 name: "Schedule",
                 configuration: {
                   cron: "invalid",
                 },
               },
             ],
             connections: [],
           }

      expect(response.status).to eq(422)
    ensure
      DiscourseWorkflows::Registry.reset!
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/workflows/:id" do
    it "updates a workflow" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            name: "Updated Name",
            enabled: true,
            nodes: [{ client_id: "t1", type: "trigger:topic_closed", name: "Topic Closed" }],
            connections: [],
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["workflow"]).to include(
        "name" => "Updated Name",
        "enabled" => true,
      )
    end

    it "returns 400 when name is missing" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json", params: { nodes: [] }

      expect(response.status).to eq(400)
    end

    it "returns 404 when workflow does not exist" do
      put "/admin/plugins/discourse-workflows/workflows/-1.json", params: { name: "Test" }

      expect(response.status).to eq(404)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/workflows/:id" do
    it "deletes a workflow" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      delete "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json"

      expect(response.status).to eq(204)
      expect(DiscourseWorkflows::Workflow.exists?(workflow.id)).to eq(false)
    end

    it "returns 404 when workflow does not exist" do
      delete "/admin/plugins/discourse-workflows/workflows/-1.json"
      expect(response.status).to eq(404)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/workflows/:id" do
    it "returns the workflow with nodes and connections" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:topic_closed",
        name: "Trigger",
        position_index: 0,
      )

      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["workflow"]["nodes"].length).to eq(1)
    end

    it "returns 404 when workflow does not exist" do
      get "/admin/plugins/discourse-workflows/workflows/-1.json"
      expect(response.status).to eq(404)
    end
  end
end
