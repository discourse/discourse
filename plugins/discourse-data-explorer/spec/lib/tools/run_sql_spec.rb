# frozen_string_literal: true

describe DiscourseDataExplorer::Tools::RunSql do
  fab!(:llm_model)
  fab!(:admin)
  fab!(:user)

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.data_explorer_enabled = true
    SiteSetting.ai_bot_enabled = true
  end

  def invoke_with(user:)
    described_class.new(
      { sql: "SELECT 1 AS one" },
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

  it "blocks a non-admin caller without running the SQL" do
    allow(DiscourseDataExplorer::DataExplorer).to receive(:run_query)

    result = invoke_with(user: user)

    expect(result[:status]).to eq("error")
    expect(result[:error]).to eq(I18n.t("discourse_data_explorer.errors.tool_not_allowed"))
    expect(DiscourseDataExplorer::DataExplorer).not_to have_received(:run_query)
  end
end
