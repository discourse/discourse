# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::QueryGeneration do
  fab!(:admin)
  fab!(:user)

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.data_explorer_enabled = true
    SiteSetting.data_explorer_ai_queries_enabled = true
  end

  it "rejects non-admin callers" do
    expect { described_class.call(user: user, ai_description: "List users") }.to raise_error(Discourse::InvalidAccess)
  end

  it "rejects disabled generation" do
    SiteSetting.data_explorer_ai_queries_enabled = false
    expect { described_class.call(user: admin, ai_description: "List users") }.to raise_error(Discourse::InvalidAccess)
  end

  it "rejects a disabled plugin" do
    SiteSetting.data_explorer_enabled = false
    expect { described_class.call(user: admin, ai_description: "List users") }.to raise_error(Discourse::InvalidAccess)
  end

  it "rejects an empty request" do
    expect { described_class.call(user: admin, ai_description: "") }.to raise_error(Discourse::InvalidParameters)
  end

  it "returns a draft without persisting it and preserves refinement context" do
    record = instance_double(AiAgent, class_instance: DiscourseDataExplorer::AiQueryGenerator)
    agent_id = DiscourseAi::Agents::Agent.external_agent_id(DiscourseDataExplorer::AiQueryGenerator)
    allow(AiAgent).to receive(:find_by).with(id: agent_id).and_return(record)
    bot = instance_double(DiscourseAi::Agents::Bot)
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
    allow(bot).to receive(:reply) do |context|
      expect(context.user).to eq(admin)
      expect(context.feature_name).to eq("data_explorer_query_generation")
      expect(context.messages.first[:content]).to include("SELECT 1", "List users")
      context.feature_context[DiscourseDataExplorer::Tools::SubmitQuery::CONTEXT_KEY] = { sql: "SELECT 2" }
    end

    result = nil
    expect { result = described_class.call(user: admin, ai_description: "List users", existing_sql: "SELECT 1") }.not_to change { DiscourseDataExplorer::Query.count }
    expect(result).to eq(sql: "SELECT 2", name: "List users", description: "List users")
  end
end
