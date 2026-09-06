# frozen_string_literal: true

require "rails_helper"

describe AiApiRequestStat do
  describe ".record_from_audit_log" do
    let(:user) { Fabricate(:user) }
    let(:llm_model) { Fabricate(:llm_model) }
    let(:log) do
      AiApiAuditLog.create!(
        user: user,
        provider_id: 1,
        language_model: "gpt-4",
        feature_name: "test",
        request_tokens: 10,
        response_tokens: 20,
        estimated_cost: 0.42,
        created_at: 1.hour.ago,
      )
    end

    it "creates a stat record with full timestamp" do
      expect { described_class.record_from_audit_log(log, llm_model: llm_model) }.to change {
        described_class.count
      }.by(1)

      stat = described_class.last
      expect(stat.bucket_date).to eq_time(log.created_at)
      expect(stat.rolled_up).to eq(false)
      expect(stat.usage_count).to eq(1)
      expect(stat.estimated_cost).to eq(BigDecimal("0.42"))
    end
  end

  describe ".rollup!" do
    before { SiteSetting.ai_usage_rollup_after_days = 1 }

    it "rolls up stats older than cutoff into daily aggregates" do
      # Old data - to be rolled up (Day 1)
      day1 = 3.days.ago.beginning_of_day
      _stat1 =
        AiApiRequestStat.create!(
          bucket_date: day1 + 1.hour,
          created_at: day1 + 1.hour,
          user_id: 1,
          provider_id: 1,
          feature_name: "test",
          usage_count: 1,
          request_tokens: 10,
          response_tokens: 10,
          estimated_cost: 0.10,
        )
      _stat2 =
        AiApiRequestStat.create!(
          bucket_date: day1 + 2.hours,
          created_at: day1 + 2.hours,
          user_id: 1,
          provider_id: 1,
          feature_name: "test",
          usage_count: 1,
          request_tokens: 20,
          response_tokens: 20,
          estimated_cost: 0.20,
        )

      # Old data - Day 2
      day2 = 2.days.ago.beginning_of_day
      _stat3 =
        AiApiRequestStat.create!(
          bucket_date: day2 + 1.hour,
          created_at: day2 + 1.hour,
          user_id: 1,
          provider_id: 1,
          feature_name: "test",
          usage_count: 1,
          request_tokens: 5,
          response_tokens: 5,
          estimated_cost: 0.05,
        )

      # Recent data - should not be rolled up
      recent_time = Time.zone.now
      _stat4 =
        AiApiRequestStat.create!(
          bucket_date: recent_time,
          created_at: recent_time,
          user_id: 1,
          provider_id: 1,
          feature_name: "test",
          usage_count: 1,
          request_tokens: 5,
          response_tokens: 5,
        )

      described_class.rollup!

      # Expect 3 records:
      # 1. Rolled up Day 1
      # 2. Rolled up Day 2
      # 3. Recent unrolled
      expect(described_class.count).to eq(3)

      day1_rollup = described_class.find_by(bucket_date: day1.beginning_of_day)
      expect(day1_rollup.rolled_up).to eq(true)
      expect(day1_rollup.usage_count).to eq(2)
      expect(day1_rollup.request_tokens).to eq(30)
      expect(day1_rollup.estimated_cost).to eq(BigDecimal("0.3"))

      day2_rollup = described_class.find_by(bucket_date: day2.beginning_of_day)
      expect(day2_rollup.rolled_up).to eq(true)
      expect(day2_rollup.usage_count).to eq(1)
      expect(day2_rollup.request_tokens).to eq(5)
      expect(day2_rollup.estimated_cost).to eq(BigDecimal("0.05"))

      recent = described_class.find_by(rolled_up: false)
      expect(recent.bucket_date).to eq_time(recent_time)
      expect(recent.estimated_cost).to be_nil
    end

    it "fills missing estimated costs during rollup when model costs are configured" do
      llm_model = Fabricate(:llm_model, input_cost: 1.0, output_cost: 2.0)
      day = 3.days.ago.beginning_of_day

      described_class.create!(
        bucket_date: day + 1.hour,
        created_at: day + 1.hour,
        llm_id: llm_model.id,
        language_model: llm_model.name,
        provider_id: 1,
        feature_name: "test",
        usage_count: 1,
        request_tokens: 100_000,
        response_tokens: 100_000,
        estimated_cost: nil,
      )
      described_class.create!(
        bucket_date: day + 2.hours,
        created_at: day + 2.hours,
        llm_id: llm_model.id,
        language_model: llm_model.name,
        provider_id: 1,
        feature_name: "test",
        usage_count: 1,
        request_tokens: 100_000,
        response_tokens: 100_000,
        estimated_cost: 0.50,
      )

      described_class.rollup!

      rollup = described_class.find_by(bucket_date: day.beginning_of_day, rolled_up: true)
      expect(rollup.usage_count).to eq(2)
      expect(rollup.estimated_cost).to eq(BigDecimal("0.8"))
    end
  end
end
