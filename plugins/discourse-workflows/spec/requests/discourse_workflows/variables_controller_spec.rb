# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::VariablesController do
  fab!(:admin)

  before do
    SiteSetting.discourse_workflows_enabled = true
    sign_in(admin)
  end

  describe "GET /admin/plugins/discourse-workflows/variables" do
    it "returns variables" do
      variable = Fabricate(:discourse_workflows_variable)

      get "/admin/plugins/discourse-workflows/variables.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["variables"].length).to eq(1)
      expect(json["variables"][0]["key"]).to eq(variable.key)
    end

    it "returns meta with total rows" do
      Fabricate(:discourse_workflows_variable)

      get "/admin/plugins/discourse-workflows/variables.json"

      json = response.parsed_body
      expect(json["meta"]["total_rows_variables"]).to eq(1)
    end

    it "paginates with cursor param" do
      variable_1 = Fabricate(:discourse_workflows_variable, key: "FIRST")
      variable_2 = Fabricate(:discourse_workflows_variable, key: "SECOND")

      get "/admin/plugins/discourse-workflows/variables.json",
          params: {
            cursor: variable_2.id,
            limit: 10,
          }

      json = response.parsed_body
      expect(json["variables"].length).to eq(1)
      expect(json["variables"][0]["id"]).to eq(variable_1.id)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/variables" do
    it "creates a variable" do
      post "/admin/plugins/discourse-workflows/variables.json",
           params: {
             key: "API_URL",
             value: "https://example.com",
             description: "API base",
           }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["variable"]["key"]).to eq("API_URL")
      expect(json["variable"]["value"]).to eq("https://example.com")
    end

    it "returns 400 when key is missing" do
      post "/admin/plugins/discourse-workflows/variables.json", params: { value: "test" }
      expect(response.status).to eq(400)
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/variables/:id" do
    it "updates a variable" do
      variable = Fabricate(:discourse_workflows_variable)

      put "/admin/plugins/discourse-workflows/variables/#{variable.id}.json",
          params: {
            key: "UPDATED_KEY",
            value: "updated",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["variable"]["key"]).to eq("UPDATED_KEY")
    end

    it "returns 404 when variable does not exist" do
      put "/admin/plugins/discourse-workflows/variables/-1.json", params: { key: "X", value: "Y" }
      expect(response.status).to eq(404)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/variables/:id" do
    it "deletes a variable" do
      variable = Fabricate(:discourse_workflows_variable)

      delete "/admin/plugins/discourse-workflows/variables/#{variable.id}.json"

      expect(response.status).to eq(204)
      expect(DiscourseWorkflows::Variable.exists?(variable.id)).to eq(false)
    end

    it "returns 404 when variable does not exist" do
      delete "/admin/plugins/discourse-workflows/variables/-1.json"
      expect(response.status).to eq(404)
    end
  end
end
