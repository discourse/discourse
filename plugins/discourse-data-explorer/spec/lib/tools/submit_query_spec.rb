# frozen_string_literal: true

describe DiscourseDataExplorer::Tools::SubmitQuery do
  fab!(:llm_model)
  fab!(:admin)

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin) }

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_bot_enabled = true
  end

  it "describes SQL as the exact validated query" do
    sql_param = described_class.signature[:parameters].find { |param| param[:name] == "sql" }

    expect(sql_param[:description]).to include("exact SQL from the final successful run_sql call")
    expect(sql_param[:description]).to include("including -- [params] comments")
  end

  it "stores the generated query on the bot context and stops the tool chain" do
    context.feature_context[described_class::VALIDATED_SQL_KEY] = "SELECT id AS user_id FROM users"

    tool =
      described_class.new(
        {
          name: "Recent users",
          description: "Lists recent users",
          sql: "SELECT id AS user_id FROM users",
        },
        bot_user: bot_user,
        llm: llm,
        context: context,
      )

    result = tool.invoke

    expect(result[:status]).to eq("success")
    expect(context.feature_context[described_class::CONTEXT_KEY]).to eq(
      {
        name: "Recent users",
        description: "Lists recent users",
        sql: "SELECT id AS user_id FROM users",
      },
    )
    expect(tool.chain_next_response?).to eq(false)
  end

  it "keeps the chain going when the submitted SQL was not validated" do
    tool =
      described_class.new(
        {
          name: "Recent users",
          description: "Lists recent users",
          sql: "SELECT id AS user_id FROM users",
        },
        bot_user: bot_user,
        llm: llm,
        context: context,
      )

    result = tool.invoke

    expect(result[:status]).to eq("error")
    expect(context.feature_context[described_class::CONTEXT_KEY]).to be_nil
    expect(tool.chain_next_response?).to eq(true)
  end

  it "stores the normalized SQL that matched validation" do
    context.feature_context[described_class::VALIDATED_SQL_KEY] = "SELECT id AS user_id FROM users"

    tool =
      described_class.new(
        {
          name: "Recent users",
          description: "Lists recent users",
          sql: " SELECT id AS user_id FROM users;\n",
        },
        bot_user: bot_user,
        llm: llm,
        context: context,
      )

    result = tool.invoke

    expect(result[:status]).to eq("success")
    expect(context.feature_context[described_class::CONTEXT_KEY][:sql]).to eq(
      "SELECT id AS user_id FROM users",
    )
  end
end
