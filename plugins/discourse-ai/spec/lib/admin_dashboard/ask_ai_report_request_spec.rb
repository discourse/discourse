# frozen_string_literal: true

describe DiscourseAi::AdminDashboard::AskAiReportRequest do
  fab!(:admin)
  fab!(:llm_model)

  before do
    enable_current_plugin
    SiteSetting.ai_ask_ai_enabled = true
    allow(SiteSetting).to receive(:ai_default_llm_model).and_return(llm_model.id)
    freeze_time Time.utc(2026, 9, 9, 12)
  end

  it "reuses the snapshot across requesters and only enqueues one job" do
    ask = AskAiLog.create!(user: admin, query: "猫", asked_at: Time.current)
    report = described_class.call(user: admin, start_date: "2026-09-01", end_date: "2026-09-09")
    other_admin = Fabricate(:admin)

    expect(
      described_class.call(
        user: other_admin,
        start_date: "2026-09-01",
        end_date: "2026-09-09",
        send_to_groups: true,
      ).id,
    ).to eq(report.id)
    expect(report.selected_logs.pluck(:id)).to eq([ask.id])
    expect(report).to have_attributes(
      requested_by_id: admin.id,
      send_to_groups: false,
      reported_ask_count: 1,
    )
    expect_job_enqueued(job: :generate_ask_ai_report, args: { report_id: report.id })
    expect(Jobs::GenerateAskAiReport.jobs.size).to eq(1)
  end

  it "allows a manual replacement for an abandoned report" do
    AskAiLog.create!(user: admin, query: "Question", asked_at: Time.current)
    previous = described_class.call(user: admin, start_date: "2026-09-01", end_date: "2026-09-09")
    previous.update!(report_status: :running)
    freeze_time 31.minutes.from_now

    replacement =
      described_class.call(user: admin, start_date: "2026-09-01", end_date: "2026-09-09")

    expect(previous.reload).to be_report_status_failed
    expect(replacement.id).not_to eq(previous.id)
    expect(replacement).to be_report_status_queued
  end

  it "creates a new snapshot when more asks arrive" do
    AskAiLog.create!(user: admin, query: "First", asked_at: Time.current)
    first = described_class.call(user: admin, start_date: "2026-09-01", end_date: "2026-09-09")
    AskAiLog.create!(user: admin, query: "Second", asked_at: Time.current)
    second = described_class.call(user: admin, start_date: "2026-09-01", end_date: "2026-09-09")

    expect(second.id).not_to eq(first.id)
    expect(first.reported_ask_count).to eq(1)
    expect(second.reported_ask_count).to eq(2)
  end

  it "rejects unauthorized recipients, invalid ranges, and empty periods" do
    expect {
      described_class.call(
        user: Fabricate(:moderator),
        start_date: "2026-09-01",
        end_date: "2026-09-09",
      )
    }.to raise_error(Discourse::InvalidAccess)
    ["groups", [1]].each do |send_to_groups|
      expect {
        described_class.call(
          user: admin,
          start_date: "2026-09-01",
          end_date: "2026-09-09",
          send_to_groups:,
        )
      }.to raise_error(Discourse::InvalidParameters)
    end
    [
      %w[invalid 2026-09-09],
      %w[2026-09-09 2026-09-01],
      %w[2020-01-01 2026-09-09],
      %w[2026-09-10 2026-09-11],
      %w[2026-09-01 2026-09-09],
    ].each do |first, last|
      expect {
        described_class.call(user: admin, start_date: first, end_date: last)
      }.to raise_error(Discourse::InvalidParameters)
    end
  end

  it "limits the snapshot and keeps its full coverage count" do
    SiteSetting.ai_ask_ai_report_max_asks = 2
    3.times { AskAiLog.create!(user: admin, query: "Question", asked_at: Time.current) }
    report = described_class.call(user: admin, start_date: "2026-09-01", end_date: "2026-09-09")
    expect(report).to have_attributes(reported_ask_count: 2, total_ask_count: 3)
    expect(report.selected_logs.count).to eq(2)
  end

  it "does not replace a deleted selected ask with an older unselected ask" do
    SiteSetting.ai_ask_ai_report_max_asks = 2
    older = AskAiLog.create!(user: admin, query: "Older", asked_at: 3.minutes.ago)
    middle = AskAiLog.create!(user: admin, query: "Middle", asked_at: 2.minutes.ago)
    newest = AskAiLog.create!(user: admin, query: "Newest", asked_at: 1.minute.ago)
    report = described_class.call(user: admin, start_date: "2026-09-01", end_date: "2026-09-09")
    expect(report.selected_logs.pluck(:id)).to eq([newest.id, middle.id])
    newest.destroy!
    expect(report.selected_logs.pluck(:id)).not_to include(older.id)
  end

  it "keeps the request sample when an ask arrives before the report row is inserted" do
    SiteSetting.ai_ask_ai_report_max_asks = 2
    first = AskAiLog.create!(user: admin, query: "First", asked_at: 1.minute.ago)
    second = AskAiLog.create!(user: admin, query: "Second", asked_at: 30.seconds.ago)
    allow(AskAiReport).to receive(:create!).and_wrap_original do |method, **args|
      freeze_time 1.second.from_now
      AskAiLog.create!(user: admin, query: "Arrived during request", asked_at: Time.current)
      method.call(**args)
    end
    report = described_class.call(user: admin, start_date: "2026-09-01", end_date: "2026-09-09")
    expect(report.selected_logs.pluck(:id)).to eq([second.id, first.id])
  end

  it "supports custom periods longer than a year while keeping the sample bounded" do
    SiteSetting.ai_ask_ai_report_max_asks = 1
    2.times { AskAiLog.create!(user: admin, query: "Question", asked_at: Time.current) }
    report = described_class.call(user: admin, start_date: "2024-01-01", end_date: "2026-09-09")
    expect(report).to have_attributes(total_ask_count: 2, reported_ask_count: 1)
  end
end
