# frozen_string_literal: true

RSpec.describe DiscourseAi::Discord::Bot::PersonaReplier do
  let(:interaction_body) do
    { data: { options: [{ value: "test query" }] }, token: "interaction_token" }.to_json.to_s
  end
  let(:persona_replier) { described_class.new(interaction_body) }

  fab!(:llm_model)
  fab!(:persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }

  before do
    enable_current_plugin
    SiteSetting.ai_discord_search_persona = persona.id.to_s

    DiscourseAi::Personas::Bot
      .any_instance
      .stubs(:reply)
      .with(is_a(DiscourseAi::Personas::BotContext))
      .returns([["Mock Reply"]])

    persona_replier.stubs(:create_reply)
  end

  describe "#handle_interaction!" do
    it "creates and updates replies" do
      persona_replier.handle_interaction!
      expect(persona_replier).to have_received(:create_reply).at_least(:once)
    end
  end
end
