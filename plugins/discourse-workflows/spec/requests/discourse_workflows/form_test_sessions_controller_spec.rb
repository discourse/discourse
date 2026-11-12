# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::FormTestSessionsController do
  fab!(:admin)
  fab!(:workflow) do
    graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:form" }
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: false, **graph)
  end

  describe "POST /admin/plugins/discourse-workflows/workflows/:id/form-test-sessions.json" do
    it "requires an admin" do
      sign_in(Fabricate(:user))

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/form-test-sessions.json",
           params: {
             trigger_node_id: "trigger-1",
           }

      expect(response).to have_http_status(:not_found)
    end

    it "creates a short-lived form test session" do
      sign_in(admin)

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/form-test-sessions.json",
           params: {
             trigger_node_id: "trigger-1",
           }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["test_url"]).to match(%r{\A/workflows/form-test/[0-9a-f-]{36}\z})
    end
  end
end
