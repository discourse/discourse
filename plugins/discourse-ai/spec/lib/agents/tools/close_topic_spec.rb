# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::CloseTopic do
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

  it "closes the topic when closed is true" do
    result = tool(topic_id: topic.id, closed: true, reason: "Off-topic discussion").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.closed).to eq(true)
  end

  it "opens the topic when closed is false" do
    topic.update!(closed: true)

    result = tool(topic_id: topic.id, closed: false, reason: "Reopening for discussion").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.closed).to eq(false)
  end

  it "posts the reason as a small action when public_reason is true" do
    result =
      tool(
        topic_id: topic.id,
        closed: true,
        reason: "Off-topic discussion",
        public_reason: true,
      ).invoke

    expect(result[:status]).to eq("success")
    small_action = topic.ordered_posts.last
    expect(small_action.post_type).to eq(Post.types[:small_action])
    expect(small_action.raw).to eq("Off-topic discussion")
  end

  it "does not post the reason when public_reason is false" do
    result =
      tool(
        topic_id: topic.id,
        closed: true,
        reason: "Off-topic discussion",
        public_reason: false,
      ).invoke

    expect(result[:status]).to eq("success")
    small_action = topic.ordered_posts.last
    expect(small_action.raw).to be_blank
  end

  it "returns an error when topic is not found" do
    result = tool(topic_id: -1, closed: true, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(topic_id: topic.id, closed: true, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { topic_id: topic.id, closed: true, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
