# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowAiAgentCatalog do
  fab!(:admin)
  fab!(:matching_agent) do
    Fabricate(
      :ai_agent,
      name: "Workflow triage helper",
      description: "Classifies incoming support posts.",
      system_prompt: "Decide whether a Discourse support post needs urgent triage.",
      enabled: true,
    )
  end

  fab!(:disabled_agent) do
    Fabricate(
      :ai_agent,
      name: "Disabled triage helper",
      description: "Old support classifier.",
      system_prompt: "Classify support posts.",
      enabled: false,
    )
  end

  subject(:result) do
    described_class.new(
      { query: query, include_disabled: include_disabled },
      bot_user: Discourse.system_user,
      llm: nil,
      context: bot_context,
    ).invoke
  end

  let(:query) { "support triage" }
  let(:include_disabled) { false }
  let(:bot_context) { DiscourseAi::Agents::BotContext.new(messages: [], user: admin) }

  it "returns enabled AI agents matching the query", :aggregate_failures do
    expect(result[:status]).to eq("success")
    expect(result[:agents]).to contain_exactly(
      include(
        id: matching_agent.id,
        name: matching_agent.name,
        description: matching_agent.description,
        enabled: true,
        system_prompt_excerpt: matching_agent.system_prompt,
      ),
    )
  end

  context "when disabled agents are included" do
    let(:query) { "old" }
    let(:include_disabled) { true }

    it "returns disabled matches for awareness", :aggregate_failures do
      expect(result[:agents]).to contain_exactly(
        include(id: disabled_agent.id, name: disabled_agent.name, enabled: false),
      )
    end
  end
end
