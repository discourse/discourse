# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::CredentialsController do
  fab!(:admin)

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/credentials.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/credentials" do
    it "returns credentials with redacted data" do
      credential = Fabricate(:discourse_workflows_credential, name: "Test Auth")

      get "/admin/plugins/discourse-workflows/credentials.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["credentials"].length).to eq(1)
      expect(json["credentials"][0]["name"]).to eq("Test Auth")
      expect(json["credentials"][0]["data"]["user"]).to eq("admin")
      expect(json["credentials"][0]["data"]["password"]).to eq(
        DiscourseWorkflows::Credential::REDACTED_VALUE,
      )
      expect(json["credentials"][0]["data_modes"]["user"]).to eq("fixed")
      expect(json["credentials"][0]["data_modes"]["password"]).to eq("fixed")
    end

    it "returns shared pagination meta" do
      Fabricate(:discourse_workflows_credential, name: "First")
      credential = Fabricate(:discourse_workflows_credential, name: "Second")

      get "/admin/plugins/discourse-workflows/credentials.json", params: { limit: 1 }

      json = response.parsed_body
      expect(json["meta"]).to include(
        "total_rows" => 2,
        "load_more_url" =>
          "/admin/plugins/discourse-workflows/credentials.json?cursor=#{credential.id}&limit=1",
      )
    end

    it "filters by type param" do
      Fabricate(:discourse_workflows_credential, credential_type: "basic_auth")
      Fabricate(:discourse_workflows_credential, credential_type: "api_key", name: "API")

      get "/admin/plugins/discourse-workflows/credentials.json", params: { type: "basic_auth" }

      json = response.parsed_body
      expect(json["credentials"].length).to eq(1)
      expect(json["credentials"][0]["credential_type"]).to eq("basic_auth")
    end
  end

  describe "POST /admin/plugins/discourse-workflows/credentials" do
    it "creates a credential" do
      post "/admin/plugins/discourse-workflows/credentials.json",
           params: {
             name: "My Auth",
             credential_type: "basic_auth",
             data: {
               user: "admin",
               password: "secret",
             },
           }

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["credential"]["name"]).to eq("My Auth")
      expect(json["credential"]["data"]["user"]).to eq("admin")
    end

    it "returns 400 when name is missing" do
      post "/admin/plugins/discourse-workflows/credentials.json",
           params: {
             credential_type: "basic_auth",
             data: {
             },
           }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/credentials/:id" do
    it "updates a credential with sentinel merging" do
      credential = Fabricate(:discourse_workflows_credential)

      put "/admin/plugins/discourse-workflows/credentials/#{credential.id}.json",
          params: {
            name: "Updated",
            data: {
              user: "new_user",
              password: DiscourseWorkflows::Credential::REDACTED_VALUE,
            },
          }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["credential"]["name"]).to eq("Updated")
      expect(credential.reload.data["user"]).to eq("new_user")
      expect(credential.reload.data["password"]).to eq("secret")
    end

    it "returns 404 when credential does not exist" do
      put "/admin/plugins/discourse-workflows/credentials/-1.json", params: { name: "X" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/credentials/:id" do
    it "deletes a credential" do
      credential = Fabricate(:discourse_workflows_credential)

      delete "/admin/plugins/discourse-workflows/credentials/#{credential.id}.json"

      expect(response).to have_http_status(:no_content)
      expect(DiscourseWorkflows::Credential.exists?(credential.id)).to be(false)
    end

    it "returns 404 when credential does not exist" do
      delete "/admin/plugins/discourse-workflows/credentials/-1.json"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when credential is referenced by a node" do
      credential = Fabricate(:discourse_workflows_credential)
      graph =
        build_workflow_graph do |g|
          g.node "webhook-1",
                 "trigger:webhook",
                 parameters: {
                   "authentication" => "basic_auth",
                 },
                 credentials: {
                   "auth" => {
                     "id" => credential.id,
                     "credential_type" => "basic_auth",
                   },
                 }
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, name: "My Workflow", created_by: admin, **graph)

      delete "/admin/plugins/discourse-workflows/credentials/#{credential.id}.json"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["type"]).to eq("credential_in_use")
      expect(response.parsed_body["referencing_workflows"]).to contain_exactly(
        { "id" => workflow.id, "name" => "My Workflow" },
      )
    end
  end
end
