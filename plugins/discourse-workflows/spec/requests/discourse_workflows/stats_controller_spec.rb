# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::StatsController do
  fab!(:admin)

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/stats.json"
      expect(response.status).to eq(404)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/stats" do
    it "returns stats JSON" do
      get "/admin/plugins/discourse-workflows/stats.json"

      expect(response.status).to eq(200)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/stats/:workflow_id" do
    fab!(:workflow, :discourse_workflows_workflow)

    it "returns stats JSON scoped to the workflow" do
      get "/admin/plugins/discourse-workflows/stats/#{workflow.id}.json"

      expect(response.status).to eq(200)
    end
  end
end
