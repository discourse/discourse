# frozen_string_literal: true

RSpec.describe Jobs::BackfillAiApiRequestStats do
  before do
    enable_current_plugin
    SiteSetting.ai_usage_rollup_after_days = 7
    freeze_time Time.zone.parse("2025-11-22 12:00:00 UTC")
  end

  let(:job) { described_class.new }

  it "backfills audit logs into stats and rolls up older data" do
    recent_log =
      AiApiAuditLog.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: 1,
        feature_name: "ai_helper",
        language_model: "claude-3-opus",
        request_tokens: 100,
        response_tokens: 50,
        cache_read_tokens: 10,
        cache_write_tokens: 5,
        created_at: 2.days.ago,
      )

    2.times do
      AiApiAuditLog.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: 2,
        feature_name: "ai_bot",
        language_model: "claude-3-opus",
        request_tokens: 25,
        response_tokens: 10,
        cache_read_tokens: 5,
        created_at: 9.days.ago,
      )
    end

    expect { job.execute_onceoff }.to change { AiApiRequestStat.count }.by(2)

    recent_stat = AiApiRequestStat.find_by(user_id: recent_log.user_id, rolled_up: false)
    expect(recent_stat.request_tokens).to eq(100)
    expect(recent_stat.response_tokens).to eq(50)
    expect(recent_stat.usage_count).to eq(1)

    rolled_stat = AiApiRequestStat.find_by(user_id: 2, feature_name: "ai_bot", rolled_up: true)
    expect(rolled_stat.usage_count).to eq(2)
    expect(rolled_stat.request_tokens).to eq(50)
    expect(rolled_stat.response_tokens).to eq(20)
    expect(rolled_stat.cache_read_tokens).to eq(10)
  end

  it "ignores audit logs newer than existing stats" do
    AiApiRequestStat.create!(
      provider_id: 1,
      feature_name: "existing",
      language_model: "claude-3-opus",
      request_tokens: 1,
      response_tokens: 1,
      created_at: 1.day.ago,
    )

    AiApiAuditLog.create!(
      provider_id: AiApiAuditLog::Provider::Anthropic,
      feature_name: "newer",
      language_model: "claude-3-opus",
      request_tokens: 10,
      response_tokens: 5,
      created_at: 12.hours.ago,
    )

    expect { job.execute_onceoff }.not_to change { AiApiRequestStat.count }
  end
end
