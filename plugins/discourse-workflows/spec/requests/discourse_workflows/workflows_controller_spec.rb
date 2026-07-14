# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowsController do
  fab!(:admin)

  before do
    SiteSetting.tagging_enabled = true
    sign_in(admin)
  end

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404 for index" do
      get "/admin/plugins/discourse-workflows/workflows.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/workflows" do
    it "returns workflows for authenticated users with access" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      get "/admin/plugins/discourse-workflows/workflows.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["workflows"].length).to eq(1)
      expect(json["workflows"][0]["name"]).to eq(workflow.name)
    end

    it "returns the latest execution status for each workflow" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      Fabricate(:discourse_workflows_error_execution, workflow: workflow, created_at: 2.hours.ago)
      Fabricate(
        :discourse_workflows_completed_execution,
        workflow: workflow,
        created_at: 1.hour.ago,
      )

      get "/admin/plugins/discourse-workflows/workflows.json"

      expect(response).to have_http_status(:ok)
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
      stub_const(DiscourseWorkflows::Pagination, "DEFAULT_LIMIT", 1) do
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
      expect(json["workflows"][0]["id"]).to eq(workflow_1.id.to_s)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/workflows" do
    fab!(:tag)

    it "creates a workflow" do
      post "/admin/plugins/discourse-workflows/workflows.json",
           params: {
             workflow: {
               name: "My Workflow",
               nodes: [
                 { id: "t1", type: "trigger:topic_closed", name: "Topic Closed" },
                 {
                   id: "a1",
                   type: "action:topic_tags",
                   name: "Topic Tags",
                   parameters: {
                     topic_id: "={{ $trigger.topic_id }}",
                     tag_names: tag.name,
                   },
                 },
               ],
               connections: {
                 "Topic Closed" => {
                   "main" => [[{ "node" => "Topic Tags", "type" => "main", "index" => 0 }]],
                 },
               },
               static_data: {
                 "node:Topic Closed" => {
                   "cursor" => "abc",
                 },
               },
             },
           },
           as: :json

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["workflow"]["name"]).to eq("My Workflow")
      expect(json["workflow"]["nodes"].length).to eq(2)
      expect(json["workflow"]["connections"].keys).to contain_exactly("Topic Closed")
      expect(json["workflow"]["static_data"]).to eq("node:Topic Closed" => { "cursor" => "abc" })
    end

    it "returns 400 when name is missing" do
      post "/admin/plugins/discourse-workflows/workflows.json", params: { workflow: { nodes: [] } }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 422 when node validation fails" do
      post "/admin/plugins/discourse-workflows/workflows.json",
           params: {
             workflow: {
               name: "Invalid Schedule",
               nodes: [
                 {
                   id: "t1",
                   type: "trigger:schedule",
                   name: "Schedule",
                   parameters: {
                     rule: {
                       interval: [{ field: "cronExpression", expression: "invalid" }],
                     },
                   },
                 },
               ],
               connections: {
               },
             },
           }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/workflows/:id" do
    it "updates a workflow" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            workflow: {
              name: "Updated Name",
              nodes: [{ id: "t1", type: "trigger:topic_closed", name: "Topic Closed" }],
              connections: {
              },
            },
          }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow"]).to include("name" => "Updated Name")
      expect(response.parsed_body["workflow"]["active_version_id"]).to be_nil
    end

    it "publishes a workflow draft" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            workflow: {
              published: true,
            },
          }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow"]["active_version_id"]).to eq(
        workflow.reload.active_version_id,
      )
    end

    it "unpublishes a workflow" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            workflow: {
              published: false,
            },
          }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow"]["active_version_id"]).to be_nil
      expect(workflow.reload.active_version_id).to be_nil
    end

    it "updates error_workflow_id" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: admin)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            workflow: {
              error_workflow_id: error_wf.id,
            },
          }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow"]["error_workflow_id"]).to eq(error_wf.id)
      expect(workflow.reload.error_workflow_id).to eq(error_wf.id)
    end

    it "returns 422 when error_workflow_id points to the workflow itself" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            workflow: {
              error_workflow_id: workflow.id,
            },
          }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(workflow.reload.error_workflow_id).to be_nil
    end

    it "clears error_workflow_id" do
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: admin)
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: admin, error_workflow_id: error_wf.id)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            workflow: {
              error_workflow_id: nil,
            },
          }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow"]["error_workflow_id"]).to be_nil
      expect(workflow.reload.error_workflow_id).to be_nil
    end

    it "preserves error_workflow_id when omitted" do
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: admin)
      graph =
        build_workflow_graph { |graph_builder| graph_builder.node "trigger-1", "trigger:manual" }
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          error_workflow_id: error_wf.id,
          **graph,
        )

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            workflow: {
              name: workflow.name,
              nodes: workflow.nodes,
              connections: workflow.connections,
            },
          }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow"]["error_workflow_id"]).to eq(error_wf.id)
      expect(workflow.reload.error_workflow_id).to eq(error_wf.id)
    end

    it "updates graph data without changing the name when name is omitted" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, name: "Original")

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            workflow: {
              nodes: [{ id: "t1", type: "trigger:manual", name: "Manual" }],
              connections: {
              },
            },
          }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow"]).to include("name" => "Original")
      expect(workflow.reload.nodes.first["name"]).to eq("Manual")
    end

    it "returns 400 when name is blank" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            workflow: {
              name: "",
            },
          }

      expect(response).to have_http_status(:bad_request)
    end

    it "returns referenced workflows when the workflow is called by another workflow" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
      caller_graph =
        build_workflow_graph do |workflow_graph|
          workflow_graph.node "trigger-1", "trigger:manual"
          workflow_graph.node "call-1",
                              "action:workflow_call",
                              configuration: {
                                "workflow_id" => workflow.id,
                              }
        end
      caller =
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **caller_graph)

      delete "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to include(
        "type" => "workflow_called_by_other_workflows",
        "referencing_workflows" => [include("id" => caller.id, "name" => caller.name)],
      )
      expect(DiscourseWorkflows::Workflow.exists?(workflow.id)).to be(true)
    end

    it "returns 404 when workflow does not exist" do
      put "/admin/plugins/discourse-workflows/workflows/-1.json",
          params: {
            workflow: {
              name: "Test",
            },
          }

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when graph population fails" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json",
          params: {
            workflow: {
              name: "Updated",
              nodes: [
                {
                  id: "t1",
                  type: "trigger:schedule",
                  name: "Schedule",
                  parameters: {
                    rule: {
                      interval: [{ field: "cronExpression", expression: "invalid" }],
                    },
                  },
                },
              ],
              connections: {
              },
            },
          }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/workflows/:id/pin-data" do
    fab!(:workflow) do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:post_created" }
      Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    end

    it "persists pinned items unwrapped from ActionController::Parameters" do
      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/pin-data.json",
          params: {
            node_name: "Trigger-1",
            items: [{ json: { post: { id: 42 } } }],
          },
          as: :json

      expect(response).to have_http_status(:no_content)
      expect(workflow.reload.pin_data["Trigger-1"].first["json"]).to eq("post" => { "id" => 42 })
    end

    it "unpins when no items are provided" do
      workflow.update_node_pin_data!("Trigger-1", [{ "json" => { "x" => 1 } }])

      put "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/pin-data.json",
          params: {
            node_name: "Trigger-1",
          },
          as: :json

      expect(response).to have_http_status(:no_content)
      expect(workflow.reload.pin_data).not_to have_key("Trigger-1")
    end
  end

  describe "POST /admin/plugins/discourse-workflows/workflows/:id/discard-draft" do
    it "restores a workflow to its published version" do
      published_graph =
        build_workflow_graph { |builder| builder.node "published-1", "trigger:manual" }
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          published: true,
          **published_graph,
        )
      published_version = workflow.active_version
      draft_graph = build_workflow_graph { |builder| builder.node "draft-1", "trigger:schedule" }
      workflow.update!(
        name: "Draft workflow",
        nodes: draft_graph[:nodes],
        connections: draft_graph[:connections],
      )
      workflow.snapshot!(user: admin)

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/discard-draft.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow"]).to include(
        "name" => published_version.name,
        "nodes" => published_version.nodes,
        "connections" => published_version.connections,
        "version_id" => published_version.version_id,
        "active_version_id" => published_version.version_id,
        "has_unpublished_changes" => false,
      )
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/workflows/:id" do
    it "deletes a workflow" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      delete "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json"

      expect(response).to have_http_status(:no_content)
      expect(DiscourseWorkflows::Workflow.exists?(workflow.id)).to be(false)
    end

    it "returns 404 when workflow does not exist" do
      delete "/admin/plugins/discourse-workflows/workflows/-1.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/workflows/:id" do
    it "returns the workflow with nodes and connections" do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["workflow"]["nodes"].length).to eq(1)
    end

    it "returns 404 when workflow does not exist" do
      get "/admin/plugins/discourse-workflows/workflows/-1.json"
      expect(response).to have_http_status(:not_found)
    end

    it "includes error_workflow_name when error workflow is set" do
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: admin, name: "Error handler")
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: admin, error_workflow_id: error_wf.id)

      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow"]["error_workflow_name"]).to eq("Error handler")
    end

    it "does not include error_workflow_name when no error workflow is set" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["workflow"]).not_to have_key("error_workflow_name")
    end
  end
end
