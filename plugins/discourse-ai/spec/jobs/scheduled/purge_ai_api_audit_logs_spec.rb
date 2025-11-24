# frozen_string_literal: true

RSpec.describe Jobs::PurgeAiApiAuditLogs do
  before do
    enable_current_plugin
    SiteSetting.ai_audit_logs_purge_after_days = 180
    freeze_time Time.zone.parse("2025-11-22 12:00:00 UTC")
  end

  let(:job) { described_class.new }

  it "removes audit logs older than the retention window" do
    recent = AiApiAuditLog.create!(provider_id: 1, created_at: 10.days.ago)
    stale = AiApiAuditLog.create!(provider_id: 1, created_at: 181.days.ago)

    expect { job.execute({}) }.to change { AiApiAuditLog.count }.by(-1)

    expect(AiApiAuditLog.exists?(recent.id)).to be(true)
    expect(AiApiAuditLog.exists?(stale.id)).to be(false)
  end

  it "does nothing when retention is disabled" do
    SiteSetting.ai_audit_logs_purge_after_days = 0
    AiApiAuditLog.create!(provider_id: 1, created_at: 400.days.ago)

    expect { job.execute({}) }.not_to change { AiApiAuditLog.count }
  end
end
