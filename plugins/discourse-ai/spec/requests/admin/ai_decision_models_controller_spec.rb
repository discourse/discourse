# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiDecisionModelsController do
  fab!(:admin)
  fab!(:ai_secret)

  let(:valid_attrs) do
    {
      display_name: "Jev",
      name: "jev-latest",
      provider: "system_one",
      url: "https://api.typesafe.ai/v1/systemone",
      ai_secret_id: ai_secret.id,
      vision_enabled: false,
    }
  end

  before do
    enable_current_plugin
    sign_in(admin)
  end

  describe "GET #index" do
    fab!(:decision_model)

    it "lists decision models with providers, presets and secrets" do
      get "/admin/plugins/discourse-ai/ai-decision-models.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["ai_decision_models"].map { |dm| dm["id"] }).to contain_exactly(
        decision_model.id,
      )
      expect(response.parsed_body.dig("meta", "providers")).to eq(%w[system_one open_ai])
      expect(
        response.parsed_body.dig("meta", "presets").map { |preset| preset["preset_id"] },
      ).to eq(%w[jev-latest vllm-sr-d3 gpt-6-luna])
      expect(
        response.parsed_body.dig("meta", "ai_secrets").map { |secret| secret["id"] },
      ).to include(ai_secret.id)
    end

    it "is not accessible to moderators" do
      sign_in(Fabricate(:moderator))

      get "/admin/plugins/discourse-ai/ai-decision-models.json"

      expect(response.status).to eq(404)
    end
  end

  describe "POST #create" do
    it "creates a decision model and logs the staff action" do
      post "/admin/plugins/discourse-ai/ai-decision-models.json",
           params: {
             ai_decision_model: valid_attrs,
           }

      expect(response.status).to eq(201)
      expect(DecisionModel.last).to have_attributes(valid_attrs)
      expect(
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "create_ai_decision_model",
        ).count,
      ).to eq(1)
    end

    it "returns an error for an unknown provider" do
      post "/admin/plugins/discourse-ai/ai-decision-models.json",
           params: {
             ai_decision_model: valid_attrs.merge(provider: "nope"),
           }

      expect(response.status).to eq(422)
      expect(DecisionModel.count).to eq(0)
    end
  end

  describe "PUT #update" do
    fab!(:decision_model)

    it "updates the decision model and logs the staff action" do
      put "/admin/plugins/discourse-ai/ai-decision-models/#{decision_model.id}.json",
          params: {
            ai_decision_model: {
              display_name: "Jev (prod)",
            },
          }

      expect(response.status).to eq(200)
      expect(decision_model.reload.display_name).to eq("Jev (prod)")
      expect(
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "update_ai_decision_model",
        ).count,
      ).to eq(1)
    end
  end

  describe "DELETE #destroy" do
    fab!(:decision_model)

    it "deletes the decision model and logs the staff action" do
      delete "/admin/plugins/discourse-ai/ai-decision-models/#{decision_model.id}.json"

      expect(response.status).to eq(204)
      expect(DecisionModel.exists?(decision_model.id)).to eq(false)
      expect(
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "delete_ai_decision_model",
        ).count,
      ).to eq(1)
    end
  end

  describe "POST #test" do
    it "asks the model a test question" do
      stub_request(:post, valid_attrs[:url]).to_return(
        status: 200,
        body: { model: "jev-1.13.0", answers: { greeting: { type: "noul", noul: 0.98 } } }.to_json,
      )

      post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
           params: {
             ai_decision_model: valid_attrs,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("success" => true, "probability" => 0.98)
    end

    it "reports provider errors" do
      stub_request(:post, valid_attrs[:url]).to_return(
        status: 401,
        body: { error: { message: "Invalid API key" } }.to_json,
      )

      post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
           params: {
             ai_decision_model: valid_attrs,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(false)
      expect(response.parsed_body["error"]).to include("401: Invalid API key")
    end
  end
end
