# frozen_string_literal: true

RSpec.describe AiUsageSerializer do
  fab!(:user)
  fab!(:claude_model) do
    Fabricate(
      :llm_model,
      name: "claude-3-opus",
      provider: "anthropic",
      input_cost: 15.0,
      output_cost: 75.0,
    )
  end

  fab!(:gpt_model) do
    Fabricate(:llm_model, name: "gpt-4", provider: "open_ai", input_cost: 10.0, output_cost: 30.0)
  end

  before { enable_current_plugin }

  describe "#feature_models" do
    it "returns a hash mapping feature names to model breakdowns" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        feature_name: "ai_bot",
        request_tokens: 1000,
        response_tokens: 500,
        created_at: 1.day.ago,
      )

      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::OpenAI,
        user_id: user.id,
        llm_id: gpt_model.id,
        language_model: "gpt-4",
        feature_name: "ai_bot",
        request_tokens: 2000,
        response_tokens: 1000,
        created_at: 1.day.ago,
      )

      report = DiscourseAi::Completions::Report.new(start_date: 2.days.ago, end_date: Time.current)
      serialized = described_class.new(report, root: false)
      json = JSON.parse(serialized.to_json)

      expect(json).to have_key("feature_models")
      expect(json["feature_models"]).to be_a(Hash)
      expect(json["feature_models"]).to have_key("ai_bot")
      expect(json["feature_models"]["ai_bot"].size).to eq(2)
    end

    it "includes credit_allocation for models with LlmCreditAllocation" do
      seeded_model = Fabricate(:seeded_model)
      Fabricate(:llm_credit_allocation, llm_model: seeded_model)

      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: seeded_model.id,
        language_model: seeded_model.name,
        feature_name: "ai_helper",
        request_tokens: 500,
        response_tokens: 250,
        created_at: 1.day.ago,
      )

      report = DiscourseAi::Completions::Report.new(start_date: 2.days.ago, end_date: Time.current)
      serialized = described_class.new(report, root: false)
      json = JSON.parse(serialized.to_json)

      ai_helper_models = json["feature_models"]["ai_helper"]
      seeded_model_data = ai_helper_models.find { |m| m["llm_id"].to_i == seeded_model.id }

      expect(seeded_model_data).to have_key("credit_allocation")
      expect(seeded_model_data["credit_allocation"]).to be_present
    end

    it "does not include credit_allocation for models without LlmCreditAllocation" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        feature_name: "ai_bot",
        request_tokens: 1000,
        response_tokens: 500,
        created_at: 1.day.ago,
      )

      report = DiscourseAi::Completions::Report.new(start_date: 2.days.ago, end_date: Time.current)
      serialized = described_class.new(report, root: false)
      json = JSON.parse(serialized.to_json)

      ai_bot_models = json["feature_models"]["ai_bot"]
      claude_model_data = ai_bot_models.find { |m| m["llm_id"].to_i == claude_model.id }

      expect(claude_model_data).not_to have_key("credit_allocation")
    end

    it "includes spending data for each model in the breakdown" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        feature_name: "ai_bot",
        request_tokens: 1000,
        response_tokens: 500,
        created_at: 1.day.ago,
      )

      report = DiscourseAi::Completions::Report.new(start_date: 2.days.ago, end_date: Time.current)
      serialized = described_class.new(report, root: false)
      json = JSON.parse(serialized.to_json)

      ai_bot_models = json["feature_models"]["ai_bot"]
      model_data = ai_bot_models.first

      expect(model_data).to have_key("input_spending")
      expect(model_data).to have_key("output_spending")
      expect(model_data).to have_key("total_tokens")
      expect(model_data).to have_key("usage_count")
    end
  end
end
