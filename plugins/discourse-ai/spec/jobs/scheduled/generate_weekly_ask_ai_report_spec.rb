# frozen_string_literal: true

describe Jobs::GenerateWeeklyAskAiReport do
  fab!(:admin)
  fab!(:user)
  fab!(:llm_model)

  before do
    enable_current_plugin
    SiteSetting.ai_ask_ai_enabled = true
    allow(SiteSetting).to receive(:ai_default_llm_model).and_return(llm_model.id)
    freeze_time Time.utc(2026, 9, 16, 12)
  end

  it "skips a week containing only questions from excluded groups" do
    SiteSetting.ai_ask_ai_report_weekly_enabled = true
    group = Fabricate(:group)
    group.add(user)
    SiteSetting.ai_ask_ai_report_exclude_groups = group.id.to_s
    AskAiLog.create!(user:, query: "Excluded question", asked_at: 1.day.ago)

    expect { described_class.new.execute({}) }.not_to change(AskAiReport, :count)
    expect(Jobs::GenerateAskAiReport.jobs).to be_empty
  end

  it "does not generate automatically by default" do
    AskAiLog.create!(user:, query: "Question", asked_at: 1.day.ago)
    expect(SiteSetting.ai_ask_ai_report_weekly_enabled).to eq(false)
    expect { described_class.new.execute({}) }.not_to change(AskAiReport, :count)
  end

  it "skips empty periods and respects the Ask AI switches" do
    SiteSetting.ai_ask_ai_report_weekly_enabled = true
    expect { described_class.new.execute({}) }.not_to change(AskAiReport, :count)
    AskAiLog.create!(user:, query: "Question", asked_at: 1.day.ago)
    SiteSetting.ai_ask_ai_enabled = false
    expect { described_class.new.execute({}) }.not_to change(AskAiReport, :count)
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.discourse_ai_enabled = false
    expect { described_class.new.execute({}) }.not_to change(AskAiReport, :count)
  end

  it "generates the previous seven complete days once and delivers to the configured groups" do
    SiteSetting.ai_ask_ai_report_weekly_enabled = true
    first = AskAiLog.create!(user:, query: "Start of week", asked_at: Time.utc(2026, 9, 9))
    last =
      AskAiLog.create!(user:, query: "End of week", asked_at: Time.utc(2026, 9, 15, 23, 59, 59))
    AskAiLog.create!(user:, query: "Too old", asked_at: Time.utc(2026, 9, 8, 23, 59, 59))
    AskAiLog.create!(user:, query: "Today", asked_at: Time.current)
    described_class.new.execute({})
    report = AskAiReport.last
    expect(report).to have_attributes(
      start_date: Date.new(2026, 9, 9),
      end_date: Date.new(2026, 9, 15),
      requested_by_id: Discourse::SYSTEM_USER_ID,
      send_to_groups: true,
      selected_ask_ids: [last.id, first.id],
      total_ask_count: 2,
    )
    expect { described_class.new.execute({}) }.not_to change(AskAiReport, :count)
    expect(Jobs::GenerateAskAiReport.jobs.size).to eq(1)

    output = {
      insights: [],
      summary: "Weekly report",
      subjects: [
        {
          name: "Questions",
          description: "Questions asked this week",
          ask_ids: [first.id, last.id],
        },
      ],
    }
    DiscourseAi::Completions::Llm.with_prepared_responses([output.to_json]) do
      Jobs::GenerateAskAiReport.new.execute(report_id: report.id)
    end
    expect(report.reload).to be_report_status_completed
    expect(report.topic.allowed_groups.pluck(:name)).to eq(["admins"])
    expect(report.subjects.first.ask_ai_logs).to contain_exactly(first, last)
  end

  it "keeps automatic reports separate from manual requests for the same period" do
    SiteSetting.ai_ask_ai_report_weekly_enabled = true
    AskAiLog.create!(user:, query: "Question", asked_at: 1.day.ago)
    described_class.new.execute({})
    automatic = AskAiReport.last
    manual =
      DiscourseAi::AdminDashboard::AskAiReportRequest.call(
        user: admin,
        start_date: automatic.start_date,
        end_date: automatic.end_date,
      )
    expect(manual.id).not_to eq(automatic.id)
    expect(manual.requested_by).to eq(admin)
    expect { described_class.new.execute({}) }.not_to change(AskAiReport, :count)
  end

  it "does not generate a queued automatic report after weekly reporting is disabled" do
    SiteSetting.ai_ask_ai_report_weekly_enabled = true
    AskAiLog.create!(user:, query: "Question", asked_at: 1.day.ago)
    described_class.new.execute({})
    report = AskAiReport.last
    SiteSetting.ai_ask_ai_report_weekly_enabled = false
    allow(DiscourseAi::Completions::Llm).to receive(:proxy).and_call_original
    Jobs::GenerateAskAiReport.new.execute(report_id: report.id)
    expect(report.reload).to be_report_status_failed
    expect(report.topic_id).to be_nil
    expect(DiscourseAi::Completions::Llm).not_to have_received(:proxy)
  end

  it "keeps automatic reports on the dashboard when no recipient groups are configured" do
    SiteSetting.ai_ask_ai_report_weekly_enabled = true
    SiteSetting.ai_ask_ai_report_recipient_groups = ""
    ask = AskAiLog.create!(user:, query: "Question", asked_at: 1.day.ago)
    described_class.new.execute({})
    report = AskAiReport.last
    output = {
      insights: [],
      summary: "Weekly report",
      subjects: [
        { name: "Questions", description: "Questions asked this week", ask_ids: [ask.id] },
      ],
    }
    DiscourseAi::Completions::Llm.with_prepared_responses([output.to_json]) do
      Jobs::GenerateAskAiReport.new.execute(report_id: report.id)
    end
    expect(report.reload).to be_report_status_completed
    expect(report.topic_id).to be_nil
    expect(report.summary).to eq("Weekly report")
    expect(report.subjects.first.ask_ai_logs).to contain_exactly(ask)
  end
end
