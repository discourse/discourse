# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::CredentialsController do
  fab!(:admin)

  before do
    SiteSetting.discourse_workflows_enabled = true
    sign_in(admin)
    DiscourseWorkflows::Registry.register_credential_type(
      DiscourseWorkflows::CredentialTypes::BasicAuth,
    )
  end

  describe "GET /admin/plugins/discourse-workflows/credentials" do
    it "returns credentials with redacted data" do
      credential = Fabricate(:discourse_workflows_credential, name: "Test Auth")

      get "/admin/plugins/discourse-workflows/credentials.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["credentials"].length).to eq(1)
      expect(json["credentials"][0]["name"]).to eq("Test Auth")
      expect(json["credentials"][0]["data"]["user"]).to eq("admin")
      expect(json["credentials"][0]["data"]["password"]).to eq("__REDACTED__")
      expect(json["credentials"][0]["data_modes"]["user"]).to eq("fixed")
      expect(json["credentials"][0]["data_modes"]["password"]).to eq("fixed")
    end

    it "returns meta with total rows" do
      Fabricate(:discourse_workflows_credential)

      get "/admin/plugins/discourse-workflows/credentials.json"

      json = response.parsed_body
      expect(json["meta"]["total_rows_credentials"]).to eq(1)
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

      expect(response.status).to eq(200)
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

      expect(response.status).to eq(400)
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
              password: "__REDACTED__",
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["credential"]["name"]).to eq("Updated")
      expect(credential.reload.decrypted_data["user"]).to eq("new_user")
      expect(credential.reload.decrypted_data["password"]).to eq("secret")
    end

    it "returns 404 when credential does not exist" do
      put "/admin/plugins/discourse-workflows/credentials/-1.json", params: { name: "X" }

      expect(response.status).to eq(404)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/credentials/:id" do
    it "deletes a credential" do
      credential = Fabricate(:discourse_workflows_credential)

      delete "/admin/plugins/discourse-workflows/credentials/#{credential.id}.json"

      expect(response.status).to eq(204)
      expect(DiscourseWorkflows::Credential.exists?(credential.id)).to eq(false)
    end

    it "returns 404 when credential does not exist" do
      delete "/admin/plugins/discourse-workflows/credentials/-1.json"
      expect(response.status).to eq(404)
    end

    it "returns 422 when credential is referenced by a node" do
      credential = Fabricate(:discourse_workflows_credential)
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:webhook",
        name: "Webhook",
        configuration: {
          "credential_id" => credential.id,
        },
      )

      delete "/admin/plugins/discourse-workflows/credentials/#{credential.id}.json"

      expect(response.status).to eq(422)
    end
  end
end
