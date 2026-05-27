# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::VariablesController do
  fab!(:admin)

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404 for index" do
      get "/admin/plugins/discourse-workflows/variables.json"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for create" do
      post "/admin/plugins/discourse-workflows/variables.json", params: { key: "X", value: "Y" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/variables" do
    it "returns variables" do
      variable = Fabricate(:discourse_workflows_variable)

      get "/admin/plugins/discourse-workflows/variables.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["variables"].length).to eq(1)
      expect(json["variables"][0]["key"]).to eq(variable.key)
      expect(json["variables"][0]["created_by"]["username"]).to eq(variable.created_by.username)
    end

    it "returns shared pagination meta" do
      Fabricate(:discourse_workflows_variable, key: "FIRST")
      variable = Fabricate(:discourse_workflows_variable, key: "SECOND")

      get "/admin/plugins/discourse-workflows/variables.json", params: { limit: 1 }

      json = response.parsed_body
      expect(json["meta"]).to include(
        "total_rows" => 2,
        "load_more_url" =>
          "/admin/plugins/discourse-workflows/variables.json?cursor=#{variable.id}&limit=1",
      )
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

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["variable"]).to include(
        "key" => "API_URL",
        "value" => "https://example.com",
        "created_by" => include("username" => admin.username),
      )
    end

    it "returns 400 when key is missing" do
      post "/admin/plugins/discourse-workflows/variables.json", params: { value: "test" }
      expect(response).to have_http_status(:bad_request)
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

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["variable"]["key"]).to eq("UPDATED_KEY")
    end

    it "returns 404 when variable does not exist" do
      put "/admin/plugins/discourse-workflows/variables/-1.json", params: { key: "X", value: "Y" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/variables/:id" do
    it "deletes a variable" do
      variable = Fabricate(:discourse_workflows_variable)

      delete "/admin/plugins/discourse-workflows/variables/#{variable.id}.json"

      expect(response).to have_http_status(:no_content)
      expect(DiscourseWorkflows::Variable.exists?(variable.id)).to be(false)
    end

    it "returns 404 when variable does not exist" do
      delete "/admin/plugins/discourse-workflows/variables/-1.json"
      expect(response).to have_http_status(:not_found)
    end
  end
end
