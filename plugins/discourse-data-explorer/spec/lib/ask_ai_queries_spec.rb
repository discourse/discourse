# frozen_string_literal: true

describe DiscourseDataExplorer::Queries do
  fab!(:admin)

  before do
    enable_current_plugin
    SiteSetting.data_explorer_enabled = true
    freeze_time Time.utc(2026, 9, 10)
  end

  def run_query(id)
    query = DiscourseDataExplorer::Query.find(id)
    result =
      DiscourseDataExplorer::DataExplorer.run_query(
        query,
        { "start_date" => "2026-09-08", "end_date" => "2026-09-09" },
        current_user: admin,
      )
    expect(result[:error]).to be_nil
    result[:pg_result].to_a
  end

  it "includes the whole selected period and days without asks" do
    AskAiLog.create!(
      user: admin,
      query: "猫",
      asked_at: Time.utc(2026, 9, 8),
      ask_outcome: :answered,
    )
    AskAiLog.create!(
      user: admin,
      query: "Email",
      asked_at: Time.utc(2026, 9, 8, 23, 59, 59),
      ask_outcome: :failed,
    )
    AskAiLog.create!(
      user: admin,
      query: "Excluded",
      asked_at: Time.utc(2026, 9, 10),
      ask_outcome: :answered,
    )
    AskAiLog.create!(
      user: admin,
      query: "Before",
      asked_at: Time.utc(2026, 9, 7, 23, 59, 59),
      ask_outcome: :answered,
    )

    rows = run_query(-45)
    expect(rows.map { |row| [row["date"].to_s, row["asks"].to_i] }).to eq(
      [["2026-09-08", 2], ["2026-09-09", 0]],
    )

    rows = run_query(-46)
    expect(rows.map { |row| [row["outcome"], row["asks"].to_i, row["percentage"].to_f] }).to eq(
      [["answered", 1, 50.0], ["failed", 1, 50.0]],
    )
  end

  it "includes unfinished asks and the end date's final second" do
    AskAiLog.create!(user: admin, query: "Pending", asked_at: Time.utc(2026, 9, 9, 23, 59, 59))
    expect(run_query(-46).first["outcome"]).to eq("pending")
    expect(run_query(-45).last["asks"].to_i).to eq(1)
  end
end
