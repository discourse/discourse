# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowVersionsController do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/versions.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/workflows/:workflow_id/versions" do
    it "returns versions newest first with author and metadata" do
      second_version = workflow.snapshot!(user: admin)

      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/versions.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["versions"].map { |version| version["version_number"] }).to eq([2, 1])
      expect(json["versions"][0]).to include(
        "version_id" => second_version.version_id,
        "is_current" => true,
      )
      expect(json["versions"][0]["created_by"]["username"]).to eq(admin.username)
      expect(json["meta"]["total_rows"]).to eq(2)
    end

    it "returns 404 when the workflow does not exist" do
      get "/admin/plugins/discourse-workflows/workflows/-1/versions.json"
      expect(response).to have_http_status(:not_found)
    end

    it "paginates with the version_number cursor" do
      workflow.snapshot!(user: admin) # version 2
      workflow.snapshot!(user: admin) # version 3

      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/versions.json",
          params: {
            cursor: 2,
            limit: 10,
          }

      json = response.parsed_body
      expect(json["versions"].map { |version| version["version_number"] }).to eq([1])
    end

    it "returns a load_more_url when there are more results" do
      workflow.snapshot!(user: admin) # version 2

      get "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/versions.json",
          params: {
            limit: 1,
          }

      json = response.parsed_body
      expect(json["versions"].length).to eq(1)
      expect(json["meta"]["load_more_url"]).to be_present
    end
  end

  describe "POST /admin/plugins/discourse-workflows/workflows/:workflow_id/versions/:version_id/restore" do
    it "reverts the draft to the chosen version" do
      first_version_id = workflow.version_id
      original_nodes = workflow.nodes

      graph = build_workflow_graph { |builder| builder.node "draft-1", "trigger:manual" }
      workflow.update!(nodes: graph[:nodes], connections: graph[:connections])
      workflow.snapshot!(user: admin)

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/versions/#{first_version_id}/restore.json"

      expect(response).to have_http_status(:ok)
      expect(workflow.reload.version_id).to eq(first_version_id)
      expect(workflow.nodes).to eq(original_nodes)
    end

    it "returns 404 for an unknown version" do
      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/versions/#{SecureRandom.uuid}/restore.json"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a version belonging to another workflow" do
      other_workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/versions/#{other_workflow.version_id}/restore.json"

      expect(response).to have_http_status(:not_found)
    end
  end
end
