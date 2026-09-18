# frozen_string_literal: true

describe DiscourseAi::Admin::AskAiReportsController do
  fab!(:admin)
  fab!(:user)
  fab!(:moderator)
  fab!(:llm_model)

  before do
    enable_current_plugin
    SiteSetting.ai_ask_ai_enabled = true
    allow(SiteSetting).to receive(:ai_default_llm_model).and_return(llm_model.id)
  end

  it "accepts the dashboard date range when the browser is ahead of UTC" do
    freeze_time Time.utc(2026, 9, 16, 17)
    sign_in(admin)
    ask = AskAiLog.create!(user:, query: "猫", asked_at: Time.current)
    AskAiLog.create!(user:, query: "Future", asked_at: 1.hour.from_now)
    dashboard =
      DiscourseAi::AdminDashboard::AskAi.build(
        start_date: "2026-08-19",
        end_date: "2026-09-17",
        current_user: admin,
      )

    post "/admin/plugins/discourse-ai/ask-ai-reports.json",
         params: {
           start_date: dashboard[:start_date].iso8601,
           end_date: dashboard[:end_date].iso8601,
         }

    expect(response.status).to eq(202)
    report = AskAiReport.find(response.parsed_body["report"]["id"])
    expect(report.start_date).to eq(Date.new(2026, 8, 19))
    expect(report.end_date).to eq(Date.new(2026, 9, 17))
    expect(report.selected_ask_ids).to eq([ask.id])
    expect(report.total_ask_count).to eq(1)
  end

  it "expires abandoned reports when loading the dashboard and returns saved summaries" do
    sign_in(admin)
    report =
      AskAiReport.create!(
        requested_by: admin,
        start_date: Date.current,
        end_date: Date.current,
        total_ask_count: 1,
        reported_ask_count: 1,
        report_status: :running,
        updated_at: 31.minutes.ago,
      )
    get "/admin/plugins/discourse-ai/ask-ai-reports.json"
    expect(response.parsed_body["reports"].first["report_status"]).to eq("failed")
    report.update!(report_status: :completed, summary: "Questions about 猫.")
    get "/admin/plugins/discourse-ai/ask-ai-reports.json"
    expect(response.parsed_body["reports"].first["summary"]).to eq("Questions about 猫.")
  end

  it "only exposes the query when Data Explorer is available" do
    sign_in(admin)
    SiteSetting.data_explorer_enabled = true
    get "/admin/plugins/discourse-ai/ask-ai-reports.json"
    expect(response.parsed_body["data_explorer_query_id"]).to eq(-47)
    SiteSetting.data_explorer_enabled = false
    get "/admin/plugins/discourse-ai/ask-ai-reports.json"
    expect(response.parsed_body["data_explorer_query_id"]).to be_nil
    hide_const("DiscourseDataExplorer")
    allow(SiteSetting).to receive(:data_explorer_enabled).and_raise(NoMethodError)
    get "/admin/plugins/discourse-ai/ask-ai-reports.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["data_explorer_query_id"]).to be_nil
  end

  it "explores only saved report memberships, including overlapping subjects" do
    SiteSetting.data_explorer_enabled = true
    report =
      AskAiReport.create!(
        requested_by: admin,
        start_date: Date.current,
        end_date: Date.current,
        total_ask_count: 1,
        reported_ask_count: 1,
      )
    other_report =
      AskAiReport.create!(
        requested_by: admin,
        start_date: Date.current,
        end_date: Date.current,
        total_ask_count: 1,
        reported_ask_count: 1,
      )
    ask =
      AskAiLog.create!(
        user:,
        query: "猫",
        asked_at: Time.utc(2026, 9, 16, 7, 25),
        answer: "Stored answer",
        ask_outcome: :answered,
      )
    AskAiLog.create!(user:, query: "Not included", asked_at: Time.current)
    [report, other_report].each do |item|
      2.times do |position|
        subject =
          item.subjects.create!(
            name: "Subject #{position}",
            description: "Description",
            position:,
            ask_count: 1,
          )
        subject.ask_ai_report_subject_asks.create!(ask_ai_log: ask)
      end
    end
    attributes = DiscourseDataExplorer::Queries.default["-47"]
    query =
      DiscourseDataExplorer::Query.new(id: -47, name: attributes[:name], sql: attributes[:sql])
    result =
      DiscourseDataExplorer::DataExplorer.run_query(
        query,
        { "report_id" => report.id.to_s },
        current_user: admin,
      )
    expect(result[:error]).to be_nil
    rows = result[:pg_result].to_a
    expect(rows.size).to eq(2)
    expect(rows.first.keys).to contain_exactly(
      "subject",
      "user_id",
      "asked_at",
      "query",
      "answer_title",
      "answer",
      "outcome",
    )
    expect(rows.map { |row| row["subject"] }).to eq(["Subject 0", "Subject 1"])
    rows.each do |row|
      expect(row).to include(
        "asked_at" => "Sep 16 07:25 UTC",
        "query" => "猫",
        "answer" => "Stored answer",
        "outcome" => "answered",
      )
    end
  end

  it "requires an admin for both reading reports and requesting them" do
    [nil, moderator].each do |user|
      sign_in(user) if user
      get "/admin/plugins/discourse-ai/ask-ai-reports.json"
      expect(response.status).to eq(404)
      post "/admin/plugins/discourse-ai/ask-ai-reports.json",
           params: {
             start_date: Date.current.to_s,
             end_date: Date.current.to_s,
           }
      expect(response.status).to eq(404)
    end
  end

  it "returns the queued snapshot and report history" do
    sign_in(admin)
    AskAiLog.create!(user:, query: "猫", asked_at: Time.current)
    post "/admin/plugins/discourse-ai/ask-ai-reports.json",
         params: {
           start_date: Date.current.to_s,
           end_date: Date.current.to_s,
         }
    expect(response.status).to eq(202)
    expect(response.parsed_body["report"]).to include(
      "report_status" => "queued",
      "reported_ask_count" => 1,
    )
    get "/admin/plugins/discourse-ai/ask-ai-reports.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["reports"].size).to eq(1)
    expect(response.parsed_body).to include("recipient_groups" => ["admins"])
  end

  it "accepts a custom period longer than a year and persists its selected asks" do
    sign_in(admin)
    ask = AskAiLog.create!(user:, query: "猫", asked_at: Time.current)
    start_date = 2.years.ago.to_date.iso8601
    post "/admin/plugins/discourse-ai/ask-ai-reports.json",
         params: {
           start_date:,
           end_date: Date.current.iso8601,
         }

    expect(response.status).to eq(202)
    report = AskAiReport.find(response.parsed_body["report"]["id"])
    expect(report.selected_ask_ids).to eq([ask.id])
    expect(response.parsed_body["report"]["start_date"]).to eq(start_date)
  end

  it "rejects reports when Ask AI is disabled" do
    sign_in(admin)
    SiteSetting.ai_ask_ai_enabled = false
    post "/admin/plugins/discourse-ai/ask-ai-reports.json",
         params: {
           start_date: Date.current.to_s,
           end_date: Date.current.to_s,
         }
    expect(response.status).to eq(404)
  end

  it "paginates only surviving asks belonging to the requested subject and report" do
    sign_in(admin)
    report =
      AskAiReport.create!(
        requested_by: admin,
        start_date: Date.current,
        end_date: Date.current,
        total_ask_count: 22,
        reported_ask_count: 22,
      )
    subject =
      report.subjects.create!(
        name: "Settings",
        description: "Configuration",
        position: 0,
        ask_count: 22,
      )
    ids =
      22.times.map do |index|
        ask = AskAiLog.create!(user:, query: "猫 #{index}", asked_at: Time.current)
        subject.ask_ai_report_subject_asks.create!(ask_ai_log: ask)
        ask.id
      end
    duplicate =
      AskAiLog.create!(
        user:,
        query: "猫 21",
        asked_at: Time.current,
        answer: "Stored answer 猫",
        ask_outcome: :answered,
      )
    subject.ask_ai_report_subject_asks.create!(ask_ai_log: duplicate)
    ids[-1] = duplicate.id
    AskAiLog.where(id: ids.first).delete_all
    AskAiLog.create!(user:, query: "Unrelated", asked_at: Time.current)
    path =
      "/admin/plugins/discourse-ai/ask-ai-reports/#{report.id}/subjects/#{subject.id}/asks.json"
    get path
    expect(response.status).to eq(200)
    expect(response.parsed_body["asks"].map { |ask| ask["id"] }).to eq(ids.reverse.first(20))
    expect(response.parsed_body["asks"].first["query"]).to eq("猫 21")
    get path, params: { before: response.parsed_body["next_before"] }
    expect(response.parsed_body["asks"].map { |ask| ask["id"] }).to eq([ids[1]])
    expect(response.parsed_body["next_before"]).to be_nil
    get path.delete_suffix(".json") + "/#{duplicate.id}.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["ask"]).to include(
      "answer" => "Stored answer 猫",
      "ask_outcome" => "answered",
    )
    get path.delete_suffix(".json") + "/#{AskAiLog.order(:id).last.id}.json"
    expect(response.status).to eq(404)
    get path, params: { before: "invalid" }
    expect(response.status).to eq(400)
    get path.sub("reports/#{report.id}/", "reports/0/")
    expect(response.status).to eq(404)
    SiteSetting.ai_ask_ai_enabled = false
    get path
    expect(response.status).to eq(404)
  end

  it "restricts question browsing to admins" do
    path = "/admin/plugins/discourse-ai/ask-ai-reports/1/subjects/1/asks.json"
    [nil, moderator, Fabricate(:user)].each do |user|
      sign_in(user) if user
      get path
      expect(response.status).to eq(404)
      get path.delete_suffix(".json") + "/1.json"
      expect(response.status).to eq(404)
    end
  end
end
