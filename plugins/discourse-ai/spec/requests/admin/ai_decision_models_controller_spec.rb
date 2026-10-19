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
      custom_headers: [{ "name" => "X-Custom-Key", "value" => "sensitive-header-value" }],
    }
  end

  before do
    enable_current_plugin
    sign_in(admin)
  end

  describe "#index" do
    fab!(:decision_model)

    it "lists decision models with providers, presets and secrets" do
      decision_model.update!(custom_headers: valid_attrs[:custom_headers])
      get "/admin/plugins/discourse-ai/ai-decision-models.json"

      expect(response.status).to eq(200)
      expect(
        response.parsed_body["ai_decision_models"].map { |model| model["id"] },
      ).to contain_exactly(decision_model.id)
      expect(response.parsed_body["ai_decision_models"].first["custom_headers"]).to eq(
        valid_attrs[:custom_headers],
      )
      expect(response.parsed_body.dig("meta", "providers")).to eq(%w[system_one typesafe open_ai])
      expect(response.parsed_body.dig("meta", "custom_header_limits")).to eq(
        DecisionModel::CUSTOM_HEADER_LIMITS.stringify_keys,
      )
      expect(
        response.parsed_body.dig("meta", "presets").map { |preset| preset["preset_id"] },
      ).to eq(DecisionModel.presets.map { |preset| preset[:preset_id] })
      expect(
        response.parsed_body.dig("meta", "ai_secrets").map { |secret| secret["id"] },
      ).to include(ai_secret.id)
      expect(response.body).not_to include(ai_secret.secret, decision_model.api_key)
    end
  end

  describe "seeded decision models" do
    fab!(:seeded_model) do
      Fabricate(
        :decision_model,
        id: -1,
        ai_secret: nil,
        api_key: "seeded-key",
        url: "https://jolteon.internal/v1/systemone",
        custom_headers: [{ "name" => "X-Pool", "value" => "internal-pool" }],
      )
    end

    it "lists them with their credit status and without hosting details" do
      Fabricate(
        :decision_model_credit_allocation,
        decision_model: seeded_model,
        daily_credits: 1000,
        daily_used: 900,
      )

      get "/admin/plugins/discourse-ai/ai-decision-models.json"

      serialized = response.parsed_body["ai_decision_models"].first
      expect(serialized).to include("seeded" => true, "url" => "********")
      expect(serialized).not_to have_key("custom_headers")
      expect(serialized["credit_allocation"]).to include(
        "daily_credits" => 1000,
        "credits_remaining" => 100,
        "soft_limit_reached" => true,
        "hard_limit_reached" => false,
      )
      expect(response.body).not_to include(seeded_model.api_key, seeded_model.url, "internal-pool")
    end

    it "cannot be updated or deleted" do
      put "/admin/plugins/discourse-ai/ai-decision-models/#{seeded_model.id}.json",
          params: {
            ai_decision_model: valid_attrs,
          }
      expect(response.status).to eq(403)

      delete "/admin/plugins/discourse-ai/ai-decision-models/#{seeded_model.id}.json"
      expect(response.status).to eq(403)

      expect(seeded_model.reload).to have_attributes(
        display_name: "TypeSafe Jev",
        url: "https://jolteon.internal/v1/systemone",
      )
    end
  end

  describe "authorization" do
    fab!(:decision_model)

    it "restricts every action to administrators" do
      sign_in(Fabricate(:moderator))
      base_path = "/admin/plugins/discourse-ai/ai-decision-models"
      [
        [:get, ""],
        [:get, "/new"],
        [:get, "/#{decision_model.id}/edit"],
        [:post, ""],
        [:put, "/#{decision_model.id}"],
        [:delete, "/#{decision_model.id}"],
        [:post, "/test"],
      ].each do |method, path|
        public_send(method, "#{base_path}#{path}.json", params: { ai_decision_model: valid_attrs })
        expect(response.status).to eq(404)
      end
      expect(decision_model.reload.display_name).to eq("TypeSafe Jev")
      expect(DecisionModel.count).to eq(1)
      expect(AiApiAuditLog.count).to eq(0)
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
      expect(response.parsed_body.dig("ai_decision_model", "custom_headers")).to eq(
        valid_attrs[:custom_headers],
      )
      log = UserHistory.find_by!(custom_type: "create_ai_decision_model")
      expect(log.details).to include(ai_secret.id.to_s)
      expect(log.details).to include("[FILTERED]")
      expect(log.details).not_to include(
        ai_secret.secret,
        valid_attrs[:custom_headers].first["value"],
      )
      expect(
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "create_ai_decision_model",
        ).count,
      ).to eq(1)
    end

    it "rejects malformed header JSON, reserved headers and nonempty OpenAI headers" do
      [
        valid_attrs.merge(custom_headers: "invalid"),
        valid_attrs.merge(custom_headers: { name: "X-Token", value: "secret" }),
        valid_attrs.merge(custom_headers: { "0" => { name: "X-Token", value: "secret" } }),
        valid_attrs.merge(custom_headers: [{ name: "X-Token", value: { secret: "bad" } }]),
        valid_attrs.merge(custom_headers: [{ name: "Authorization", value: "secret" }]),
        valid_attrs.merge(provider: "open_ai"),
      ].each do |attrs|
        post "/admin/plugins/discourse-ai/ai-decision-models.json",
             params: {
               ai_decision_model: attrs,
             },
             as: :json

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end
      expect(DecisionModel.count).to eq(0)
      expect(UserHistory.where(custom_type: "create_ai_decision_model").count).to eq(0)
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

    it "persists, serializes and clears header updates without leaking values in staff logs" do
      headers = valid_attrs[:custom_headers]
      path = "/admin/plugins/discourse-ai/ai-decision-models/#{decision_model.id}.json"
      put path, params: { ai_decision_model: { custom_headers: headers } }, as: :json

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("ai_decision_model", "custom_headers")).to eq(headers)
      expect(decision_model.reload.custom_headers).to eq(headers)
      expect(UserHistory.where(custom_type: "update_ai_decision_model").last.details).to include(
        I18n.t("discourse_ai.ai_staff_action_logger.set"),
      )

      get "/admin/plugins/discourse-ai/ai-decision-models/#{decision_model.id}/edit.json"
      expect(response.parsed_body.dig("ai_decision_model", "custom_headers")).to eq(headers)

      replacement = [{ "name" => "x-custom-key", "value" => "replacement-secret" }]
      put path, params: { ai_decision_model: { custom_headers: replacement } }, as: :json
      expect(response.status).to eq(200)
      expect(decision_model.reload.custom_headers).to eq(replacement)
      expect(UserHistory.where(custom_type: "update_ai_decision_model").last.details).to include(
        I18n.t("discourse_ai.ai_staff_action_logger.updated"),
      )

      put path, params: { ai_decision_model: { display_name: "Still configured" } }, as: :json
      expect(decision_model.reload.custom_headers).to eq(replacement)

      put path, params: { ai_decision_model: { custom_headers: [] } }, as: :json
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("ai_decision_model", "custom_headers")).to eq([])
      expect(decision_model.reload.custom_headers).to eq([])
      logs = UserHistory.where(custom_type: "update_ai_decision_model").order(:id)
      expect(logs.last.details).to include(I18n.t("discourse_ai.ai_staff_action_logger.removed"))
      expect(logs.map(&:details).join).not_to include(
        headers.first["value"],
        replacement.first["value"],
      )
    end

    it "keeps persisted headers when an invalid update is rejected" do
      decision_model.update!(custom_headers: valid_attrs[:custom_headers])
      put "/admin/plugins/discourse-ai/ai-decision-models/#{decision_model.id}.json",
          params: {
            ai_decision_model: {
              custom_headers: [{ name: "Host", value: "evil" }],
            },
          },
          as: :json

      expect(response.status).to eq(422)
      expect(decision_model.reload.custom_headers).to eq(valid_attrs[:custom_headers])
      expect(UserHistory.where(custom_type: "update_ai_decision_model").count).to eq(0)
    end

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
      put "/admin/plugins/discourse-ai/ai-decision-models/#{decision_model.id}.json",
          params: {
            ai_decision_model: {
              provider: "unknown",
            },
          }
      expect(response.status).to eq(422)
      expect(decision_model.reload.provider).to eq("system_one")
    end
  end

  describe "#destroy" do
    fab!(:decision_model)

    it "deletes the decision model and logs the staff action" do
      decision_model.update!(custom_headers: valid_attrs[:custom_headers])
      delete "/admin/plugins/discourse-ai/ai-decision-models/#{decision_model.id}.json"

      expect(response.status).to eq(204)
      expect(DecisionModel.exists?(decision_model.id)).to eq(false)
      log = UserHistory.find_by!(custom_type: "delete_ai_decision_model")
      expect(log.details).to include(
        decision_model.url,
        decision_model.name,
        decision_model.ai_secret_id.to_s,
      )
      expect(log.details).to include("[FILTERED]")
      expect(log.details).not_to include(
        decision_model.api_key,
        valid_attrs[:custom_headers].first["value"],
      )
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

    it "sends unsaved custom headers when testing a model" do
      request =
        stub_request(:post, valid_attrs[:url]).with(
          headers: {
            "X-Custom-Key" => valid_attrs[:custom_headers].first["value"],
          },
        ).to_return(body: { answers: { greeting: { type: "noul", noul: 0.98 } } }.to_json)

      post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
           params: {
             ai_decision_model: valid_attrs,
           },
           as: :json

      expect(response.parsed_body).to eq("success" => true, "probability" => 0.98)
      expect(request).to have_been_requested.once
      expect(DecisionModel.count).to eq(0)
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

    it "sends a 280×280 probe image as a referenced PNG asset" do
      sent = nil
      request =
        stub_request(:post, valid_attrs[:url])
          .with do |req|
            sent = JSON.parse(req.body)
            reference = sent.dig("state", "images", 0)
            asset = sent.dig("assets", reference)
            asset && asset["type"] == "image" && asset["format"] == "png" &&
              "data:image/png;base64,#{asset["data_base64"]}" == described_class::TEST_IMAGE &&
              FastImage.size(StringIO.new(Base64.strict_decode64(asset["data_base64"]))) ==
                [280, 280] && !sent.key?("images")
          end
          .to_return(
            body: {
              answers: {
                greeting: {
                  type: "noul",
                  noul: 0.98,
                },
                red_image: {
                  type: "noul",
                  noul: 0.99,
                },
              },
            }.to_json,
          )

      post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
           params: {
             ai_decision_model: valid_attrs.merge(provider: "typesafe", vision_enabled: true),
           },
           as: :json

      expect(response.parsed_body).to eq("success" => true, "probability" => 0.98)
      expect(request).to have_been_requested.once
      payload = JSON.parse(AiApiAuditLog.last.raw_request_payload)
      expect(payload["state"]).to eq(sent["state"])
      expect(payload["assets"].keys).to eq(sent["assets"].keys)
      expect(payload["assets"].values.first["data_base64"]).to start_with("[redacted image/png,")
      expect(DecisionModel.count).to eq(0)
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

    it "reports provider errors for text and image requests" do
      [[401, false], [400, true]].each do |status, vision_enabled|
        stub_request(:post, valid_attrs[:url]).to_return(
          status:,
          body: { detail: { error_type: "api_usage_error", message: "Invalid request." } }.to_json,
        )

        post "/admin/plugins/discourse-ai/ai-decision-models/test.json",
             params: {
               ai_decision_model: valid_attrs.merge(vision_enabled:),
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(
          "success" => false,
          "error" => "Request failed with status #{status}: Invalid request.",
        )
      end
    end
  end
end
