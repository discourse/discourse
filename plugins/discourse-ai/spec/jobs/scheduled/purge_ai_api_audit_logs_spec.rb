# frozen_string_literal: true

RSpec.describe Jobs::PurgeAiApiAuditLogs do
  before do
    enable_current_plugin
    SiteSetting.ai_audit_logs_detailed_retention_days = 30
    SiteSetting.ai_audit_logs_purge_after_days = 180
    freeze_time Time.zone.parse("2025-11-22 12:00:00 UTC")
  end

  let(:job) { described_class.new }

  it "removes expired summaries and strips payloads from expired details" do
    recent =
      Fabricate(
        :ai_api_audit_log,
        raw_request_payload: "recent request",
        raw_response_payload: "recent response",
        created_at: 10.days.ago,
      )
    summary =
      Fabricate(
        :ai_api_audit_log,
        raw_request_payload: "old request",
        raw_response_payload: "old response",
        feature_context: {
          "source" => "spec",
        },
        request_attempts: [{ "status" => 429, "delay_ms" => 1_000 }],
        created_at: 31.days.ago,
      )
    expired = Fabricate(:ai_api_audit_log, raw_request_payload: "expired", created_at: 181.days.ago)

    job.execute({})

    expect(AiApiAuditLog.exists?(expired.id)).to eq(false)
    expect(recent.reload).to have_attributes(
      raw_request_payload: "recent request",
      raw_response_payload: "recent response",
    )
    expect(summary.reload).to have_attributes(
      raw_request_payload: nil,
      raw_response_payload: nil,
      feature_context: {
        "source" => "spec",
      },
      request_attempts: [{ "status" => 429, "delay_ms" => 1_000 }],
      created_at: 31.days.ago,
    )
  end

  it "keeps full details until deletion when detailed retention is zero" do
    SiteSetting.ai_audit_logs_detailed_retention_days = 0
    recent = Fabricate(:ai_api_audit_log, raw_request_payload: "kept", created_at: 179.days.ago)
    expired = Fabricate(:ai_api_audit_log, raw_request_payload: "deleted", created_at: 181.days.ago)

    job.execute({})

    expect(recent.reload.raw_request_payload).to eq("kept")
    expect(AiApiAuditLog.exists?(expired.id)).to eq(false)
  end

  it "keeps summaries forever when summary retention is zero" do
    SiteSetting.ai_audit_logs_purge_after_days = 0
    log = Fabricate(:ai_api_audit_log, raw_request_payload: "strip", created_at: 31.days.ago)

    job.execute({})

    expect(log.reload.raw_request_payload).to be_nil
    expect(AiApiAuditLog.exists?(log.id)).to eq(true)
  end

  it "does nothing when both retention periods are forever" do
    SiteSetting.ai_audit_logs_detailed_retention_days = 0
    SiteSetting.ai_audit_logs_purge_after_days = 0
    log = Fabricate(:ai_api_audit_log, raw_request_payload: "kept", created_at: 400.days.ago)

    expect { job.execute({}) }.not_to change { log.reload.attributes }
  end

  it "applies retention when Discourse AI is disabled" do
    SiteSetting.discourse_ai_enabled = false
    log = Fabricate(:ai_api_audit_log, raw_request_payload: "strip", created_at: 31.days.ago)

    job.execute({})

    expect(log.reload.raw_request_payload).to be_nil
  end

  it "processes deletion and payload stripping across batches" do
    stub_const(described_class, :BATCH_SIZE, 2) do
      expired_logs =
        Fabricate.times(
          5,
          :ai_api_audit_log,
          raw_request_payload: "delete",
          created_at: 181.days.ago,
        )
      summary_logs =
        Fabricate.times(
          5,
          :ai_api_audit_log,
          raw_request_payload: "strip",
          created_at: 31.days.ago,
        )

      job.execute({})

      expect(AiApiAuditLog.where(id: expired_logs.map(&:id))).to be_empty
      expect(AiApiAuditLog.where(id: summary_logs.map(&:id)).pluck(:raw_request_payload)).to all(
        be_nil,
      )
    end
  end

  it "handles retention settings with an inverted cutoff safely" do
    SiteSetting.ai_audit_logs_detailed_retention_days = 180
    SiteSetting.ai_audit_logs_purge_after_days = 30
    deleted = Fabricate(:ai_api_audit_log, raw_request_payload: "delete", created_at: 31.days.ago)
    retained = Fabricate(:ai_api_audit_log, raw_request_payload: "keep", created_at: 29.days.ago)

    job.execute({})

    expect(AiApiAuditLog.exists?(deleted.id)).to eq(false)
    expect(retained.reload.raw_request_payload).to eq("keep")
  end

  it "is idempotent" do
    log = Fabricate(:ai_api_audit_log, raw_request_payload: "strip", created_at: 31.days.ago)

    job.execute({})
    expect { job.execute({}) }.not_to change { log.reload.attributes }
  end
end
