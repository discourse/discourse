# frozen_string_literal: true

RSpec.describe Jobs::RollupAiApiRequestStats do
  before do
    enable_current_plugin
    SiteSetting.ai_usage_rollup_after_days = 7
    freeze_time Time.zone.parse("2025-11-22 12:00:00 UTC")
  end

  let(:job) { described_class.new }

  it "rolls up stats older than the configured window" do
    old_time = 8.days.ago
    newer_time = 2.days.ago

    2.times do |idx|
      AiApiRequestStat.create!(
        provider_id: AiApiAuditLog::Provider::Anthropic,
        user_id: 1,
        feature_name: "ai_bot",
        language_model: "claude-3-opus",
        request_tokens: 100 + idx,
        response_tokens: 50,
        cache_read_tokens: 10,
        cache_write_tokens: 5,
        created_at: old_time,
      )
    end

    AiApiRequestStat.create!(
      provider_id: AiApiAuditLog::Provider::Anthropic,
      user_id: 2,
      feature_name: "ai_helper",
      language_model: "claude-3-opus",
      request_tokens: 10,
      response_tokens: 5,
      created_at: newer_time,
    )

    expect { job.execute({}) }.to change { AiApiRequestStat.where(rolled_up: true).count }.by(1)

    rolled_up = AiApiRequestStat.find_by(rolled_up: true, bucket_date: old_time.to_date, user_id: 1)

    expect(rolled_up.request_tokens).to eq(201)
    expect(rolled_up.response_tokens).to eq(100)
    expect(rolled_up.cache_read_tokens).to eq(20)
    expect(rolled_up.cache_write_tokens).to eq(10)
    expect(rolled_up.usage_count).to eq(2)
    expect(rolled_up.created_at).to eq_time(old_time.beginning_of_day)

    expect(AiApiRequestStat.where(rolled_up: false, bucket_date: old_time.to_date).count).to eq(0)

    expect(AiApiRequestStat.where(rolled_up: false, bucket_date: newer_time.to_date).count).to eq(1)
  end
end
