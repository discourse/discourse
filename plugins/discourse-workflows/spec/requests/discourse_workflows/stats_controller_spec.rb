# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::StatsController do
  fab!(:admin)

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/stats.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/stats" do
    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:other_workflow, :discourse_workflows_workflow)

    before do
      Fabricate(:discourse_workflows_completed_execution, workflow: workflow)
      Fabricate(:discourse_workflows_error_execution, workflow: workflow)
      Fabricate(:discourse_workflows_completed_execution, workflow: other_workflow)
    end

    it "returns aggregate stats across all workflows" do
      get "/admin/plugins/discourse-workflows/stats.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include("total" => 3, "failed" => 1)
      expect(json["failure_rate"]).to match(/\A[\d.]+%\z/)
      expect(json["avg_duration"]).to match(/\A[\d.]+(ms|s)\z/)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/stats/:workflow_id" do
    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:other_workflow, :discourse_workflows_workflow)

    before do
      Fabricate(:discourse_workflows_completed_execution, workflow: workflow)
      Fabricate(:discourse_workflows_error_execution, workflow: workflow)
      Fabricate(:discourse_workflows_completed_execution, workflow: other_workflow)
    end

    it "returns stats scoped to the workflow" do
      get "/admin/plugins/discourse-workflows/stats/#{workflow.id}.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("total" => 2, "failed" => 1)
    end
  end
end
