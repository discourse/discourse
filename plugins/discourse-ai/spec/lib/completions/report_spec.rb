# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Report do
  before { enable_current_plugin }

  fab!(:user)
  fab!(:claude_model) do
    Fabricate(
      :llm_model,
      name: "claude-3-opus",
      provider: "anthropic",
      input_cost: 15.0,
      output_cost: 75.0,
      cached_input_cost: 1.5,
      cache_write_cost: 18.75,
    )
  end

  describe "llm_model join" do
    it "does not produce duplicate rows when multiple llm_models share the same name" do
      Fabricate(
        :llm_model,
        name: "claude-3-opus",
        provider: "anthropic",
        input_cost: 20.0,
        output_cost: 100.0,
      )

      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        request_tokens: 1000,
        response_tokens: 500,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)

      expect(report.total_requests).to eq(1)
      expect(report.model_breakdown.to_a.size).to eq(1)
      expect(report.user_breakdown.to_a.size).to eq(1)
      expect(report.feature_breakdown.to_a.size).to eq(1)
    end

    it "joins only on llm_id, ignoring language_model name" do
      other_model =
        Fabricate(
          :llm_model,
          name: "claude-3-opus",
          provider: "anthropic",
          input_cost: 999.0,
          output_cost: 999.0,
        )

      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        request_tokens: 1000,
        response_tokens: 500,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)

      costs = report.model_costs.to_a
      expect(costs.size).to eq(1)
      expect(costs.first.input_cost).to eq(claude_model.input_cost)
      expect(costs.first.output_cost).to eq(claude_model.output_cost)
    end

    it "returns nil costs for stats without llm_id" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: nil,
        language_model: "legacy-model",
        request_tokens: 1000,
        response_tokens: 500,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)

      costs = report.model_costs.to_a
      expect(costs.size).to eq(1)
      expect(costs.first.input_cost).to be_nil
      expect(costs.first.output_cost).to be_nil
    end
  end

  describe "#total_spending" do
    it "calculates spending with separate cache read and write costs" do
      # Create logs with different cache patterns
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        request_tokens: 1000,
        response_tokens: 500,
        cache_read_tokens: 2000,
        cache_write_tokens: 1000,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)

      # Input: 1000 * $15 / 1M = $0.015
      # Output: 500 * $75 / 1M = $0.0375
      # Cache read: 2000 * $1.5 / 1M = $0.003
      # Cache write: 1000 * $18.75 / 1M = $0.01875
      # Total: $0.07425
      expect(report.total_spending).to eq(0.07)

      expect(report.total_input_spending).to eq(0.015)
      expect(report.total_output_spending).to eq(0.0375)
      expect(report.total_cache_read_spending).to eq(0.003)
      expect(report.total_cache_write_spending).to eq(0.01875)
    end

    it "handles logs without cache tokens" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        request_tokens: 1000,
        response_tokens: 500,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)

      # Input: 1000 * $15 / 1M = $0.015
      # Output: 500 * $75 / 1M = $0.0375
      # Total: $0.0525
      expect(report.total_spending).to eq(0.05)
    end
  end

  describe "#model_breakdown" do
    it "includes separate cache read and write token counts" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        request_tokens: 1000,
        response_tokens: 500,
        cache_read_tokens: 2000,
        cache_write_tokens: 1000,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)
      breakdown = report.model_breakdown.first

      expect(breakdown.total_request_tokens).to eq(1000)
      expect(breakdown.total_response_tokens).to eq(500)
      expect(breakdown.total_cache_read_tokens).to eq(2000)
      expect(breakdown.total_cache_write_tokens).to eq(1000)
      expect(breakdown.cache_read_spending).to be_within(0.001).of(0.003)
      expect(breakdown.cache_write_spending).to be_within(0.001).of(0.01875)
    end
  end

  describe "#user_breakdown" do
    it "includes cache spending for users" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        request_tokens: 1000,
        response_tokens: 500,
        cache_read_tokens: 2000,
        cache_write_tokens: 1000,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)
      breakdown = report.user_breakdown.first

      expect(breakdown.total_cache_read_tokens).to eq(2000)
      expect(breakdown.total_cache_write_tokens).to eq(1000)
      expect(breakdown.cache_read_spending).to be_within(0.001).of(0.003)
      expect(breakdown.cache_write_spending).to be_within(0.001).of(0.01875)
    end
  end

  describe "#feature_breakdown" do
    it "includes cache spending for features" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        feature_name: "ai_bot",
        request_tokens: 1000,
        response_tokens: 500,
        cache_read_tokens: 2000,
        cache_write_tokens: 1000,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)
      breakdown = report.feature_breakdown.first

      expect(breakdown.total_cache_read_tokens).to eq(2000)
      expect(breakdown.total_cache_write_tokens).to eq(1000)
      expect(breakdown.cache_read_spending).to be_within(0.001).of(0.003)
      expect(breakdown.cache_write_spending).to be_within(0.001).of(0.01875)
    end
  end

  describe "#feature_model_breakdown" do
    fab!(:gpt_model) do
      Fabricate(:llm_model, name: "gpt-4", provider: "open_ai", input_cost: 10.0, output_cost: 30.0)
    end

    it "returns breakdown grouped by both feature and model" do
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

      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        feature_name: "ai_helper",
        request_tokens: 500,
        response_tokens: 250,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)
      breakdown = report.feature_model_breakdown.to_a

      expect(breakdown.size).to eq(3)

      ai_bot_claude =
        breakdown.find { |b| b.feature_name == "ai_bot" && b.llm_id.to_i == claude_model.id }
      expect(ai_bot_claude).to be_present
      expect(ai_bot_claude.total_request_tokens).to eq(1000)
      expect(ai_bot_claude.total_response_tokens).to eq(500)

      ai_bot_gpt =
        breakdown.find { |b| b.feature_name == "ai_bot" && b.llm_id.to_i == gpt_model.id }
      expect(ai_bot_gpt).to be_present
      expect(ai_bot_gpt.total_request_tokens).to eq(2000)
      expect(ai_bot_gpt.total_response_tokens).to eq(1000)

      ai_helper_claude =
        breakdown.find { |b| b.feature_name == "ai_helper" && b.llm_id.to_i == claude_model.id }
      expect(ai_helper_claude).to be_present
      expect(ai_helper_claude.total_request_tokens).to eq(500)
      expect(ai_helper_claude.total_response_tokens).to eq(250)
    end

    it "includes spending calculations per feature-model combination" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        feature_name: "ai_bot",
        request_tokens: 1000,
        response_tokens: 500,
        cache_read_tokens: 2000,
        cache_write_tokens: 1000,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)
      breakdown = report.feature_model_breakdown.first

      expect(breakdown.input_spending).to be_within(0.001).of(0.015)
      expect(breakdown.output_spending).to be_within(0.001).of(0.0375)
      expect(breakdown.cache_read_spending).to be_within(0.001).of(0.003)
      expect(breakdown.cache_write_spending).to be_within(0.001).of(0.01875)
    end

    it "handles unknown features" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        feature_name: nil,
        request_tokens: 1000,
        response_tokens: 500,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)
      breakdown = report.feature_model_breakdown.first

      expect(breakdown.feature_name).to eq("unknown")
    end
  end

  describe "#tokens_by_period" do
    it "includes cache token counts in period breakdowns" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: "claude-3-opus",
        request_tokens: 1000,
        response_tokens: 500,
        cache_read_tokens: 2000,
        cache_write_tokens: 1000,
        created_at: 1.day.ago,
      )

      report = described_class.new(start_date: 2.days.ago, end_date: Time.current)
      period_data = report.tokens_by_period(:day).first

      expect(period_data.total_cache_read_tokens).to eq(2000)
      expect(period_data.total_cache_write_tokens).to eq(1000)
    end
  end

  describe "#filter_by_model" do
    it "filters by seeded models with negative IDs" do
      seeded_model = Fabricate(:seeded_model)

      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: seeded_model.id,
        language_model: seeded_model.name,
        request_tokens: 500,
        response_tokens: 250,
        created_at: 1.day.ago,
      )

      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: claude_model.name,
        request_tokens: 1000,
        response_tokens: 500,
        created_at: 1.day.ago,
      )

      report =
        described_class.new(start_date: 2.days.ago, end_date: Time.current).filter_by_model(
          seeded_model.id,
        )

      expect(report.total_requests).to eq(1)
      expect(report.total_request_tokens).to eq(500)
      expect(report.total_response_tokens).to eq(250)
    end

    it "filters by regular models with positive IDs" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: claude_model.id,
        language_model: claude_model.name,
        request_tokens: 1000,
        response_tokens: 500,
        created_at: 1.day.ago,
      )

      report =
        described_class.new(start_date: 2.days.ago, end_date: Time.current).filter_by_model(
          claude_model.id,
        )

      expect(report.total_requests).to eq(1)
      expect(report.total_request_tokens).to eq(1000)
    end

    it "filters by language_model string for legacy stats" do
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
        llm_id: nil,
        language_model: "legacy-model-name",
        request_tokens: 2000,
        response_tokens: 1000,
        created_at: 1.day.ago,
      )

      report =
        described_class.new(start_date: 2.days.ago, end_date: Time.current).filter_by_model(
          "legacy-model-name",
        )

      expect(report.total_requests).to eq(1)
      expect(report.total_request_tokens).to eq(2000)
    end
  end
end
