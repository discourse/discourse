# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::TemplatesController do
  fab!(:admin)

  before do
    SiteSetting.discourse_workflows_enabled = true
    sign_in(admin)
  end

  describe "GET /admin/plugins/discourse-workflows/templates" do
    it "returns a list of templates" do
      get "/admin/plugins/discourse-workflows/templates.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["templates"]).to be_an(Array)
      expect(json["templates"].size).to be >= 1
    end

    it "returns templates with expected attributes" do
      get "/admin/plugins/discourse-workflows/templates.json"

      template = response.parsed_body["templates"].first
      expect(template["id"]).to be_present
      expect(template["name"]).to be_present
      expect(template["description"]).to be_present
      expect(template["node_types"]).to be_an(Array)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/templates/:id" do
    it "returns the template" do
      get "/admin/plugins/discourse-workflows/templates/auto-tag-topics.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["template"]["name"]).to eq("Auto-tag new topics")
      expect(json["template"]["nodes"]).to be_an(Array)
    end

    it "returns 404 when template does not exist" do
      get "/admin/plugins/discourse-workflows/templates/nonexistent.json"

      expect(response.status).to eq(404)
    end
  end
end
