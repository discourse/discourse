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
  fab!(:agent_user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:agent) { Fabricate(:ai_agent, default_llm_id: llm_model.id, user: agent_user) }

  before do
    enable_current_plugin
    SiteSetting.ai_discord_search_agent = agent.id
    SiteSetting.ai_discord_search_mode = "agent"
    SiteSetting.ai_discord_search_enabled = true
    SiteSetting.ai_discord_app_id = "discord_app"
  end

  it "runs agent tools as the agent user" do
    fake_model = Fabricate(:fake_model)
    agent.update!(
      default_llm_id: fake_model.id,
      tools: ["DeleteTopic"],
      require_approval: false,
      allowed_group_ids: [Group::AUTO_GROUPS[:everyone]],
    )
    AiAgent.agent_cache.flush!

    post = Fabricate(:post)
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "delete-topic-call",
        name: "delete_topic",
        parameters: {
          topic_id: post.topic_id,
          deleted: true,
          reason: "from discord",
        },
      )
    webhook_url = "https://discord.com/api/webhooks/discord_app/interaction_token"
    stub_request(:post, webhook_url).to_return(status: 200, body: "{}")
    stub_request(:patch, "#{webhook_url}/messages/@original").to_return(status: 200, body: "{}")

    DiscourseAi::Completions::Endpoints::Fake.with_fake_content([tool_call, "Done"]) do
      described_class.new.execute(interaction: interaction)
    end

    expect(post.reload.deleted_at).to be_nil
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
