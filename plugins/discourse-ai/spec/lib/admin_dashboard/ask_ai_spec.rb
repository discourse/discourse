# frozen_string_literal: true

describe DiscourseAi::AdminDashboard::AskAi do
  fab!(:admin)
  fab!(:user)
  fab!(:moderator)

  before { enable_current_plugin }

  it "counts outcomes, distinct askers, and observed answer latency in the selected period" do
    AskAiLog.create!(user:, query: "Earlier", asked_at: "2026-08-31 23:59:59")
    [
      [:answered, 1000],
      [:failed, 3000],
      [:no_answer, nil],
      [:cancelled, nil],
      [nil, nil],
    ].each do |outcome, latency|
      AskAiLog.create!(
        user:,
        query: "猫",
        asked_at: "2026-09-01 12:00:00",
        ask_outcome: outcome,
        time_to_first_answer_ms: latency,
      )
    end
    AskAiLog.create!(
      user: admin,
      query: "Last day",
      asked_at: "2026-09-02 23:59:59",
      ask_outcome: :answered,
      time_to_first_answer_ms: 8000,
    )
    AskAiLog.create!(
      user: admin,
      query: "Outside",
      asked_at: "2026-09-03 00:00:00",
      ask_outcome: :answered,
      time_to_first_answer_ms: 9000,
    )

    result =
      described_class.build(start_date: "2026-09-01", end_date: "2026-09-02", current_user: admin)

    expect(result).to include(questions: 6, askers: 2, average_first_answer_ms: 4000)
    expect(result[:daily_asks]).to eq([{ x: "2026-09-01", y: 5 }, { x: "2026-09-02", y: 1 }])
    expect(result[:outcomes]).to eq(
      [
        { outcome: "answered", count: 2 },
        { outcome: "no_answer", count: 1 },
        { outcome: "failed", count: 1 },
        { outcome: "cancelled", count: 1 },
        { outcome: "pending", count: 1 },
      ],
    )
  end

  it "returns zero counts and no latency for an empty period" do
    result =
      described_class.build(start_date: "2026-09-01", end_date: "2026-09-02", current_user: admin)

    expect(result).to include(questions: 0, askers: 0, average_first_answer_ms: nil)
    expect(result[:outcomes].pluck(:count)).to eq([0, 0, 0, 0, 0])
    expect(result[:daily_asks]).to eq([{ x: "2026-09-01", y: 0 }, { x: "2026-09-02", y: 0 }])
  end

  it "includes days without asks between active days" do
    %w[2026-09-01 2026-09-03].each { |date| AskAiLog.create!(user:, query: "猫", asked_at: date) }

    result =
      described_class.build(start_date: "2026-09-01", end_date: "2026-09-03", current_user: admin)

    expect(result[:daily_asks]).to eq(
      [{ x: "2026-09-01", y: 1 }, { x: "2026-09-02", y: 0 }, { x: "2026-09-03", y: 1 }],
    )
  end

  it "does not expose metrics to moderators or anonymous users" do
    [moderator, nil].each do |viewer|
      expect(described_class.build(start_date: nil, end_date: nil, current_user: viewer)).to be_nil
    end
  end

  it "uses the default window for invalid or reversed dates" do
    freeze_time Time.zone.parse("2026-09-08 12:00:00")
    AskAiLog.create!(user:, query: "Today", asked_at: Time.current)

    [%w[invalid invalid], %w[2026-09-09 2026-09-01]].each do |start_date, end_date|
      expect(described_class.build(start_date:, end_date:, current_user: admin)[:questions]).to eq(
        1,
      )
    end
  end
end
