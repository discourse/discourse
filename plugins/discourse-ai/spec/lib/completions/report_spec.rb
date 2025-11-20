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

  describe "#total_spending" do
    it "calculates spending with separate cache read and write costs" do
      # Create logs with different cache patterns
      AiApiAuditLog.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
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
      AiApiAuditLog.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
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
      AiApiAuditLog.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
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
      AiApiAuditLog.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
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
      AiApiAuditLog.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
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

  describe "#tokens_by_period" do
    it "includes cache token counts in period breakdowns" do
      AiApiAuditLog.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: user.id,
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
end
