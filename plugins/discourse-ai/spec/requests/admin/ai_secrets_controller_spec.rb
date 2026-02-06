# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiSecretsController do
  fab!(:admin)
  fab!(:user)
  fab!(:ai_secret)

  before do
    enable_current_plugin
    sign_in(admin)
  end

  describe "#index" do
    it "lists all secrets" do
      get "/admin/plugins/discourse-ai/ai-secrets.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["ai_secrets"].length).to eq(1)
      expect(json["ai_secrets"][0]["name"]).to eq(ai_secret.name)
      expect(json["ai_secrets"][0]["secret"]).to eq("********")
    end

    it "requires admin" do
      sign_in(user)
      get "/admin/plugins/discourse-ai/ai-secrets.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#show" do
    it "returns the unmasked secret" do
      get "/admin/plugins/discourse-ai/ai-secrets/#{ai_secret.id}.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["ai_secret"]["name"]).to eq(ai_secret.name)
      expect(json["ai_secret"]["secret"]).to eq(ai_secret.secret)
    end
  end

  describe "#create" do
    it "creates a new secret" do
      post "/admin/plugins/discourse-ai/ai-secrets.json",
           params: {
             ai_secret: {
               name: "New Secret",
               secret: "sk-new-key",
             },
           }

      expect(response.status).to eq(201)
      json = response.parsed_body
      expect(json["ai_secret"]["name"]).to eq("New Secret")
      expect(json["ai_secret"]["secret"]).to eq("********")
      expect(AiSecret.last.secret).to eq("sk-new-key")
      expect(AiSecret.last.created_by_id).to eq(admin.id)
    end

    it "returns errors for invalid params" do
      post "/admin/plugins/discourse-ai/ai-secrets.json",
           params: {
             ai_secret: {
               name: "",
               secret: "",
             },
           }

      expect(response.status).to eq(422)
    end
  end

  describe "#update" do
    it "updates a secret" do
      put "/admin/plugins/discourse-ai/ai-secrets/#{ai_secret.id}.json",
          params: {
            ai_secret: {
              name: "Updated Name",
              secret: "new-secret-value",
            },
          }

      expect(response.status).to eq(200)
      ai_secret.reload
      expect(ai_secret.name).to eq("Updated Name")
      expect(ai_secret.secret).to eq("new-secret-value")
    end

    it "does not update secret when masked value is sent" do
      original_secret = ai_secret.secret
      put "/admin/plugins/discourse-ai/ai-secrets/#{ai_secret.id}.json",
          params: {
            ai_secret: {
              name: "Updated Name",
              secret: "********",
            },
          }

      expect(response.status).to eq(200)
      ai_secret.reload
      expect(ai_secret.name).to eq("Updated Name")
      expect(ai_secret.secret).to eq(original_secret)
    end
  end

  describe "#destroy" do
    it "deletes an unused secret" do
      delete "/admin/plugins/discourse-ai/ai-secrets/#{ai_secret.id}.json"
      expect(response.status).to eq(204)
      expect(AiSecret.find_by(id: ai_secret.id)).to be_nil
    end

    it "refuses to delete a secret in use" do
      Fabricate(:llm_model, ai_secret: ai_secret)

      delete "/admin/plugins/discourse-ai/ai-secrets/#{ai_secret.id}.json"
      expect(response.status).to eq(409)
      expect(AiSecret.find_by(id: ai_secret.id)).to be_present
    end
  end
end
