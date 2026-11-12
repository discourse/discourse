# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::TemplatesController do
  fab!(:admin)

  before do
    DiscourseWorkflows::TemplateStore.reset_cache!
    sign_in(admin)
  end

  after { DiscourseWorkflows::TemplateStore.reset_cache! }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/templates.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/templates" do
    it "returns the templates" do
      get "/admin/plugins/discourse-workflows/templates.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["templates"].map { |t| t["id"] }).to include("auto-tag-topics")
    end
  end

  describe "GET /admin/plugins/discourse-workflows/templates/:id" do
    it "returns the template" do
      get "/admin/plugins/discourse-workflows/templates/auto-tag-topics.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["template"]["name"]).to eq("Auto-tag new topics")
      expect(json["template"]["nodes"]).to be_an(Array)
    end

    it "returns 404 when template does not exist" do
      get "/admin/plugins/discourse-workflows/templates/nonexistent.json"

      expect(response).to have_http_status(:not_found)
    end
  end
end
