# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::SetTopicTimer do
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

  it "sets a close timer on the topic" do
    result =
      tool(
        topic_id: topic.id,
        timer_type: "close",
        duration_hours: 24,
        reason: "Cooling off period",
      ).invoke

    expect(result[:status]).to eq("success")
    timer = topic.reload.public_topic_timer
    expect(timer).to be_present
    expect(timer.status_type).to eq(TopicTimer.types[:close])
  end

  it "removes a timer when duration_hours is null" do
    topic.set_or_create_timer(TopicTimer.types[:close], 24, by_user: Discourse.system_user)

    result =
      tool(
        topic_id: topic.id,
        timer_type: "close",
        duration_hours: nil,
        reason: "No longer needed",
      ).invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.public_topic_timer).to be_nil
  end

  it "returns an error for invalid timer type" do
    result =
      tool(topic_id: topic.id, timer_type: "invalid", duration_hours: 1, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when topic is not found" do
    result = tool(topic_id: -1, timer_type: "close", duration_hours: 1, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(topic_id: topic.id, timer_type: "close", duration_hours: 1, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { topic_id: topic.id, timer_type: "close", duration_hours: 1, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
