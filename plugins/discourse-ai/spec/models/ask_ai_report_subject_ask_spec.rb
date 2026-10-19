# frozen_string_literal: true

describe AskAiReportSubjectAsk do
  fab!(:admin)
  fab!(:report) do
    AskAiReport.create!(
      requested_by: admin,
      start_date: Date.current,
      end_date: Date.current,
      total_ask_count: 1,
      reported_ask_count: 1,
    )
  end
  fab!(:report_subject) do
    report.subjects.create!(
      name: "Settings",
      description: "Configuration",
      position: 0,
      ask_count: 1,
    )
  end
  fab!(:ask) { AskAiLog.create!(user: admin, query: "Settings 猫", asked_at: Time.current) }

  it "rejects duplicate membership without preventing overlap between subjects" do
    described_class.create!(ask_ai_report_subject: report_subject, ask_ai_log: ask)
    other_subject =
      report.subjects.create!(name: "Ask AI", description: "Search", position: 1, ask_count: 1)
    described_class.create!(ask_ai_report_subject: other_subject, ask_ai_log: ask)

    expect {
      described_class.transaction(requires_new: true) do
        described_class.create!(ask_ai_report_subject: report_subject, ask_ai_log: ask)
      end
    }.to raise_error(ActiveRecord::RecordNotUnique)
    expect(report_subject.ask_ai_logs).to contain_exactly(ask)
    expect(other_subject.ask_ai_logs).to contain_exactly(ask)
  end

  it "removes membership when logs are bulk deleted and preserves the report's original count" do
    described_class.create!(ask_ai_report_subject: report_subject, ask_ai_log: ask)

    AskAiLog.where(id: ask.id).delete_all

    expect(described_class.where(ask_ai_report_subject: report_subject)).to be_empty
    expect(report_subject.ask_ai_logs).to be_empty
    expect(report_subject.reload.ask_count).to eq(1)
  end

  it "removes membership when the report is deleted without deleting the original asks" do
    membership = described_class.create!(ask_ai_report_subject: report_subject, ask_ai_log: ask)

    report.destroy!

    expect(described_class.exists?(membership.id)).to eq(false)
    expect(AskAiLog.exists?(ask.id)).to eq(true)
  end
end
