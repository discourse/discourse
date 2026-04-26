# frozen_string_literal: true

RSpec.describe Jobs::StreamDiscordReply, type: :job do
  let(:interaction) do
    {
      type: 2,
      data: {
        options: [{ value: "test query" }],
      },
      token: "interaction_token",
    }.to_json.to_s
  end

  fab!(:llm_model)
  fab!(:agent) { Fabricate(:ai_agent, default_llm_id: llm_model.id) }

  before do
    enable_current_plugin
    SiteSetting.ai_discord_search_enabled = true
    SiteSetting.ai_discord_search_mode = "agent"
    SiteSetting.ai_discord_search_agent = agent.id
  end

  it "calls AgentReplier when search mode is agent" do
    expect_any_instance_of(DiscourseAi::Discord::Bot::AgentReplier).to receive(:handle_interaction!)
    described_class.new.execute(interaction: interaction)
  end

  it "calls Search when search mode is not agent" do
    SiteSetting.ai_discord_search_mode = "search"
    expect_any_instance_of(DiscourseAi::Discord::Bot::Search).to receive(:handle_interaction!)
    described_class.new.execute(interaction: interaction)
  end
end
