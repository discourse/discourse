# frozen_string_literal: true

describe Jobs::GenerateDeQueryWithAi do
  fab!(:admin)

  before do
    SiteSetting.data_explorer_enabled = true
    SiteSetting.data_explorer_ai_queries_enabled = true
  end

  def stub_agent
    agent_id = DiscourseAi::Agents::Agent.external_agent_id(DiscourseDataExplorer::AiQueryGenerator)
    agent_record = instance_double(AiAgent, class_instance: DiscourseDataExplorer::AiQueryGenerator)

    allow(AiAgent).to receive(:find_by).and_call_original
    allow(AiAgent).to receive(:find_by).with(id: agent_id).and_return(agent_record)
  end

  def stub_bot_with_submission(submission)
    bot = instance_double(DiscourseAi::Agents::Bot)

    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
    allow(bot).to receive(:reply) do |context|
      context.feature_context[DiscourseDataExplorer::Tools::SubmitQuery::CONTEXT_KEY] = submission
    end
  end

  def execute_job
    described_class.new.execute(
      generation_id: "abc123",
      user_id: admin.id,
      ai_description: "show me users",
    )
  end

  it "publishes the query submitted by the final tool" do
    stub_agent
    stub_bot_with_submission(
      {
        name: "Recent users",
        description: "Lists recent users",
        sql: "SELECT id AS user_id FROM users",
      },
    )

    messages = MessageBus.track_publish("#{described_class::CHANNEL_PREFIX}/abc123") { execute_job }

    expect(messages.first.data).to include(
      status: "complete",
      generation_id: "abc123",
      name: "Recent users",
      description: "Lists recent users",
      sql: "SELECT id AS user_id FROM users",
    )
  end

  it "publishes an error when the final tool does not submit SQL" do
    stub_agent
    stub_bot_with_submission({})

    messages = MessageBus.track_publish("#{described_class::CHANNEL_PREFIX}/abc123") { execute_job }

    expect(messages.first.data).to include(
      status: "error",
      generation_id: "abc123",
      error: I18n.t("discourse_data_explorer.ai.error_no_sql_returned"),
    )
  end
end
