# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::StatsController do
  fab!(:admin)

  before do
    SiteSetting.discourse_workflows_enabled = true
    sign_in(admin)
  end

  describe "GET /admin/plugins/discourse-workflows/stats" do
    it "returns stats JSON" do
      get "/admin/plugins/discourse-workflows/stats.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json).to have_key("total")
      expect(json).to have_key("failed")
      expect(json).to have_key("failure_rate")
      expect(json).to have_key("avg_duration")
    end
  end
end
