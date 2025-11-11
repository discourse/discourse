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
  fab!(:persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }

  before do
    enable_current_plugin
    SiteSetting.ai_discord_search_enabled = true
    SiteSetting.ai_discord_search_mode = "persona"
    SiteSetting.ai_discord_search_persona = persona.id
  end

  it "calls PersonaReplier when search mode is persona" do
    expect_any_instance_of(DiscourseAi::Discord::Bot::PersonaReplier).to receive(
      :handle_interaction!,
    )
    described_class.new.execute(interaction: interaction)
  end

  it "calls Search when search mode is not persona" do
    SiteSetting.ai_discord_search_mode = "search"
    expect_any_instance_of(DiscourseAi::Discord::Bot::Search).to receive(:handle_interaction!)
    described_class.new.execute(interaction: interaction)
  end
end
