# frozen_string_literal: true

describe DiscourseDataExplorer::Tools::RunSql do
  fab!(:llm_model)
  fab!(:admin)
  fab!(:user)
  fab!(:category)
  fab!(:group)

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.data_explorer_enabled = true
    SiteSetting.ai_bot_enabled = true
  end

  def invoke_with(user:, sql: "SELECT 1 AS one")
    described_class.new(
      { sql: sql },
      bot_user: bot_user,
      llm: llm,
      context: DiscourseAi::Agents::BotContext.new(user: user),
    ).invoke
  end

  it "returns success for an admin caller" do
    result = invoke_with(user: admin)

    expect(result[:status]).to eq("success")
    expect(result[:columns]).to eq(["one"])
  end

  it "passes the current user when validating current_user_id params" do
    result = invoke_with(user: admin, sql: <<~SQL)
          -- [params]
          -- current_user_id :me
          SELECT :me AS user_id
        SQL

    expect(result[:status]).to eq("success")
    expect(result[:columns]).to eq(["user_id"])
    expect(result[:rows]).to eq([[admin.id]])
    expect(result[:params_used]).to eq({})
  end

  it "uses representative values for required params without defaults" do
    result = invoke_with(user: admin, sql: <<~SQL)
          -- [params]
          -- category_id :category
          -- group_id :group
          SELECT :category AS category_id, :group AS group_name
        SQL

    expect(result[:status]).to eq("success")
    expect(result[:params_used]["category"]).to be_present
    expect(result[:params_used]["group"]).to be_present
  end

  it "uses representative values for list params" do
    result = invoke_with(user: admin, sql: <<~SQL)
          -- [params]
          -- int_list :ids
          SELECT 1 IN (:ids) AS has_sample
        SQL

    expect(result[:status]).to eq("success")
    expect(result[:rows]).to eq([[true]])
    expect(result[:params_used]).to eq({ "ids" => "1,2" })
  end

  it "keeps declared defaults for params" do
    result = invoke_with(user: admin, sql: <<~SQL)
          -- [params]
          -- int :limit = 7
          SELECT :limit AS selected_limit
        SQL

    expect(result[:status]).to eq("success")
    expect(result[:rows]).to eq([[7]])
    expect(result[:params_used]).to eq({})
  end

  it "uses representative values for date ranges" do
    freeze_time DateTime.parse("2026-05-26 12:00")

    result = invoke_with(user: admin, sql: <<~SQL)
          -- [params]
          -- date :start_date
          -- date :end_date
          SELECT CAST(:start_date AS date) AS start_date, CAST(:end_date AS date) AS end_date
        SQL

    expect(result[:status]).to eq("success")
    expect(result[:params_used]).to eq({ "start_date" => "2026-04-26", "end_date" => "2026-05-26" })
  end

  it "returns an actionable error for undeclared params before running SQL" do
    allow(DiscourseDataExplorer::DataExplorer).to receive(:run_query)

    result = invoke_with(user: admin, sql: <<~SQL)
          SELECT COUNT(*)
          FROM topics
          WHERE created_at >= CAST(:start_date AS date)
            AND created_at < CAST(:end_date AS date) + INTERVAL '1 day'
        SQL

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include(":start_date")
    expect(result[:error]).to include(":end_date")
    expect(result[:error]).to include("-- [params]")
    expect(DiscourseDataExplorer::DataExplorer).not_to have_received(:run_query)
  end

  it "does not treat PostgreSQL casts as undeclared params" do
    result = invoke_with(user: admin, sql: <<~SQL)
          SELECT '2026-01-01'::timestamp AS starts_at
        SQL

    expect(result[:status]).to eq("success")
    expect(result[:columns]).to eq(["starts_at"])
  end

  it "blocks a non-admin caller without running the SQL" do
    allow(DiscourseDataExplorer::DataExplorer).to receive(:run_query)

    result = invoke_with(user: user)

    expect(result[:status]).to eq("error")
    expect(result[:error]).to eq(I18n.t("discourse_data_explorer.errors.tool_not_allowed"))
    expect(DiscourseDataExplorer::DataExplorer).not_to have_received(:run_query)
  end
end
