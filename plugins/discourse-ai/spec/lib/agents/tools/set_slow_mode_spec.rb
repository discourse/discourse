# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::SetSlowMode do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:topic)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Agents::BotContext.new }

  it "enables slow mode on the topic" do
    result = tool(topic_id: topic.id, slow_mode_seconds: 600, reason: "Heated discussion").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.slow_mode_seconds).to eq(600)
  end

  it "disables slow mode when slow_mode_seconds is 0" do
    topic.update!(slow_mode_seconds: 600)

    result = tool(topic_id: topic.id, slow_mode_seconds: 0, reason: "Discussion calmed").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.slow_mode_seconds).to eq(0)
  end

  it "sets an expiration timer when duration_hours is provided" do
    result =
      tool(
        topic_id: topic.id,
        slow_mode_seconds: 300,
        duration_hours: 2,
        reason: "Temporary cooldown",
      ).invoke

    expect(result[:status]).to eq("success")
    timer = TopicTimer.find_by(topic: topic, status_type: TopicTimer.types[:clear_slow_mode])
    expect(timer).to be_present
  end

  it "returns an error when topic is not found" do
    result = tool(topic_id: -1, slow_mode_seconds: 600, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(topic_id: topic.id, slow_mode_seconds: 600, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { topic_id: topic.id, slow_mode_seconds: 600, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
