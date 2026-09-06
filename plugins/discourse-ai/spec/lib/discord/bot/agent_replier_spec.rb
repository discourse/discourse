# frozen_string_literal: true

RSpec.describe DiscourseAi::Discord::Bot::AgentReplier do
  let(:interaction_body) do
    { data: { options: [{ value: "test query" }] }, token: "interaction_token" }.to_json.to_s
  end
  let(:selected_agent) { agent }
  let(:agent_replier) { described_class.new(interaction_body) }

  fab!(:llm_model)
  fab!(:agent_user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:agent) { Fabricate(:ai_agent, default_llm_id: llm_model.id, user: agent_user) }
  fab!(:agent_without_user) { Fabricate(:ai_agent, default_llm_id: llm_model.id) }

  before do
    enable_current_plugin
    SiteSetting.ai_discord_search_agent = selected_agent.id.to_s
    allow_any_instance_of(DiscourseAi::Agents::Bot).to receive(:reply).and_return(
      [["This is a reply from bot!"]],
    )
    allow(agent_replier).to receive(:create_reply)
  end

  describe "#handle_interaction!" do
    it "creates and updates replies" do
      agent_replier.handle_interaction!
      expect(agent_replier).to have_received(:create_reply).at_least(:once)
    end

    it "passes the agent user in BotContext" do
      expect_any_instance_of(DiscourseAi::Agents::Bot).to receive(:reply) do |_bot, context|
        expect(context).to be_a(DiscourseAi::Agents::BotContext)
        expect(context.user).to eq(agent.user)
        [["This is a reply from bot!"]]
      end

      agent_replier.handle_interaction!
    end

    context "when the selected agent has no associated user" do
      let(:selected_agent) { agent_without_user }

      it "does not run the agent" do
        agent_replier.handle_interaction!

        expect(agent_replier).to have_received(:create_reply).with(
          I18n.t("discourse_ai.discord.configuration.agent_user_required"),
        )
      end
    end
  end
end
