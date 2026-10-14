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

  describe "#index" do
    fab!(:decision_model)

    it "lists decision models with providers, presets and secrets" do
      get "/admin/plugins/discourse-ai/ai-decision-models.json"

      expect(response.status).to eq(200)
      expect(
        response.parsed_body["ai_decision_models"].map { |model| model["id"] },
      ).to contain_exactly(decision_model.id)
      expect(response.parsed_body.dig("meta", "providers")).to eq(%w[system_one open_ai])
      expect(
        response.parsed_body.dig("meta", "presets").map { |preset| preset["preset_id"] },
      ).to eq(DecisionModel.presets.map { |preset| preset[:preset_id] })
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

  describe "#create" do
    it "creates a decision model and logs the staff action" do
      post "/admin/plugins/discourse-ai/ai-decision-models.json",
           params: {
             ai_decision_model: valid_attrs,
           }

      expect(response.status).to eq(201)
      expect(DecisionModel.last).to have_attributes(valid_attrs)
      log = UserHistory.find_by!(custom_type: "create_ai_decision_model")
      expect(log.details).to include(ai_secret.id.to_s)
      expect(log.details).not_to include(ai_secret.secret)
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

  describe "#update" do
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
      expect(UserHistory.find_by!(custom_type: "update_ai_decision_model").details).to include(
        "TypeSafe Jev → Jev (prod)",
      )
      expect(
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "update_ai_decision_model",
        ).count,
      ).to eq(1)
    end
  end

  describe "#destroy" do
    fab!(:decision_model)

    it "deletes the decision model and logs the staff action" do
      delete "/admin/plugins/discourse-ai/ai-decision-models/#{decision_model.id}.json"

      expect(response.status).to eq(204)
      expect(DecisionModel.exists?(decision_model.id)).to eq(false)
      log = UserHistory.find_by!(custom_type: "delete_ai_decision_model")
      expect(log.details).to include(
        decision_model.url,
        decision_model.name,
        decision_model.ai_secret_id.to_s,
      )
      expect(log.details).not_to include(decision_model.api_key)
      expect(
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "delete_ai_decision_model",
        ).count,
      ).to eq(1)
    end
  end

  describe "#test" do
    it "asks the model a test question without saving it" do
      DiscourseAi::Decisions.with_canned_answers(greeting: 0.98) do |canned|
        post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
             params: {
               ai_decision_model: valid_attrs.merge(display_name: ""),
             }
        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq("success" => true, "probability" => 0.98)
        expect(canned.calls.first).to include(
          state: "Hello! How are you doing today?",
          user: admin,
          feature_name: "decision_model_test",
        )
      end
      expect(DecisionModel.count).to eq(0)
      expect(AiApiAuditLog.count).to eq(0)
    end

    it "reports refusals and validation errors" do
      DiscourseAi::Decisions.with_canned_answers(greeting: :refusal) do
        post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
             params: {
               ai_decision_model: valid_attrs,
             }
        expect(response.parsed_body).to eq(
          "success" => false,
          "error" => I18n.t("discourse_ai.decision_models.test_refused"),
        )
      end
      post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
           params: {
             ai_decision_model: valid_attrs.merge(url: "ftp://example.com"),
           }
      expect(response.parsed_body).to include("success" => false, "error" => include("URL"))
    end

    it "checks that vision-enabled models read a test image" do
      attrs = valid_attrs.merge(vision_enabled: true)

      DiscourseAi::Decisions.with_canned_answers(greeting: 0.98, red_image: 0.97) do |canned|
        post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
             params: {
               ai_decision_model: attrs,
             }
        expect(response.parsed_body).to eq("success" => true, "probability" => 0.98)
        expect(canned.calls.first[:images]).to eq([described_class::TEST_IMAGE])
      end

      DiscourseAi::Decisions.with_canned_answers(greeting: 0.98, red_image: 0.02) do
        post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
             params: {
               ai_decision_model: attrs,
             }
        expect(response.parsed_body).to eq(
          "success" => false,
          "error" => I18n.t("discourse_ai.decision_models.test_image_not_read"),
        )
      end
    end

    it "reports providers that reject the test image" do
      stub_request(:post, valid_attrs[:url]).to_return(
        status: 400,
        body: { detail: { error_type: "api_usage_error", message: "Invalid request." } }.to_json,
      )

      post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
           params: {
             ai_decision_model: valid_attrs.merge(vision_enabled: true),
           }

      expect(response.parsed_body).to eq(
        "success" => false,
        "error" => "Request failed with status 400: Invalid request.",
      )
    end

    it "rate limits staff after six tests" do
      RateLimiter.enable
      DiscourseAi::Decisions.with_canned_answers(greeting: true) do
        6.times do
          post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
               params: {
                 ai_decision_model: valid_attrs,
               }
          expect(response.status).to eq(200)
        end
        post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
             params: {
               ai_decision_model: valid_attrs,
             }
        expect(response.status).to eq(429)
      end
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
