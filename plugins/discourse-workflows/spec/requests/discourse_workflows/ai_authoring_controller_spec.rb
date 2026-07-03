# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::AiAuthoringController do
  fab!(:admin)

  before do
    SiteSetting.discourse_workflows_ai_authoring_enabled = true
    sign_in(admin)
  end

  describe "POST /admin/plugins/discourse-workflows/workflows/ai/author" do
    it "creates a session and enqueues authoring" do
      post "/admin/plugins/discourse-workflows/workflows/ai/author.json",
           params: {
             message: "Create a manual workflow that logs hello",
             mode: "create",
           }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      session = DiscourseWorkflows::AiAuthoringSession.find(json["session_id"])
      expect(session).to have_attributes(
        user_id: admin.id,
        status: "generating",
        latest_request: "Create a manual workflow that logs hello",
      )
      expect(Jobs::DiscourseWorkflows::AuthorWithAi.jobs.last["args"].first).to include(
        "session_id" => session.id,
        "user_id" => admin.id,
        "generation_id" => json["generation_id"],
      )
    end

    it "returns not found when AI authoring is disabled" do
      SiteSetting.discourse_workflows_ai_authoring_enabled = false

      post "/admin/plugins/discourse-workflows/workflows/ai/author.json",
           params: {
             message: "Create a workflow",
             mode: "create",
           }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/workflows/:id/ai/apply" do
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    let(:operations) do
      [
        {
          op: "add_node",
          client_id: "manual-trigger",
          node: {
            type: "trigger:manual",
            name: "Manual trigger",
            position: {
              x: 0,
              y: 0,
            },
          },
        },
        {
          op: "add_node",
          client_id: "write-log",
          node: {
            type: "action:log",
            name: "Write log",
            position: {
              x: 200,
              y: 0,
            },
            parameters: {
              mode: "runOnceForAllItems",
              entries: {
                values: [{ key: "message", value: "hello" }],
              },
            },
          },
        },
        {
          op: "add_connection",
          from: "manual-trigger",
          to: "write-log",
          output_index: 0,
          input_index: 0,
        },
      ]
    end

    it "applies the stored proposal to the workflow draft" do
      session =
        Fabricate(
          :discourse_workflows_ai_authoring_session,
          user: admin,
          workflow: workflow,
          status: "proposal_ready",
          proposed_patch: {
            "operations" => operations,
          },
          base_graph_digest: DiscourseWorkflows::Ai::GraphDigest.call(workflow),
        )

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/ai/apply.json",
           params: {
             session_id: session.id,
           }

      expect(response).to have_http_status(:ok)
      expect(workflow.reload.nodes.map { |node| node["type"] }).to contain_exactly(
        "trigger:manual",
        "action:log",
      )
      expect(session.reload.status).to eq("applied")
    end

    it "applies proposals that create AI agents", :aggregate_failures do
      agent_operations = [
        {
          op: "create_ai_agent",
          client_id: "triage-agent",
          agent: {
            name: "Workflow apply triage agent",
            description: "Classifies workflow posts during apply.",
            system_prompt: "You classify Discourse posts during workflow execution.",
          },
        },
        {
          op: "add_node",
          client_id: "classify-post",
          node: {
            type: "action:ai_agent",
            name: "Classify post",
            parameters: {
              agent_id: {
                "$ref" => "triage-agent",
              },
              prompt: "={{ $json.post.raw }}",
            },
          },
        },
      ]
      session =
        Fabricate(
          :discourse_workflows_ai_authoring_session,
          user: admin,
          workflow: workflow,
          status: "proposal_ready",
          proposed_patch: {
            "operations" => agent_operations,
          },
          base_graph_digest: DiscourseWorkflows::Ai::GraphDigest.call(workflow),
        )

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/ai/apply.json",
           params: {
             session_id: session.id,
           }
      created_agent = AiAgent.find_by(name: "Workflow apply triage agent")
      node =
        workflow.reload.nodes.find { |workflow_node| workflow_node["type"] == "action:ai_agent" }

      expect(response).to have_http_status(:ok)
      expect(created_agent).to be_present
      expect(node.dig("parameters", "agent_id")).to eq(created_agent.id)
      expect(session.reload.status).to eq("applied")
    end

    it "rejects proposals that are not ready" do
      session =
        Fabricate(
          :discourse_workflows_ai_authoring_session,
          user: admin,
          workflow: workflow,
          status: "error",
          proposed_patch: {
            "operations" => operations,
          },
          base_graph_digest: DiscourseWorkflows::Ai::GraphDigest.call(workflow),
        )

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/ai/apply.json",
           params: {
             session_id: session.id,
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(workflow.reload.nodes).to eq([])
    end

    it "rejects stale proposals" do
      session =
        Fabricate(
          :discourse_workflows_ai_authoring_session,
          user: admin,
          workflow: workflow,
          status: "proposal_ready",
          proposed_patch: {
            "operations" => operations,
          },
          base_graph_digest: "stale",
        )

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/ai/apply.json",
           params: {
             session_id: session.id,
           }

      expect(response).to have_http_status(:conflict)
      expect(session.reload.status).to eq("proposal_ready")
    end
  end
end
