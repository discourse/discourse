# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::UnlistTopic do
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

  let(:context) { DiscourseAi::Personas::BotContext.new }

  it "unlists the topic when unlisted is true" do
    result = tool(topic_id: topic.id, unlisted: true, reason: "Needs cleanup").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.visible).to eq(false)
  end

  it "lists the topic when unlisted is false" do
    topic.update!(visible: false)

    result = tool(topic_id: topic.id, unlisted: false, reason: "Ready to publish").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.visible).to eq(true)
  end

  it "posts the reason as a small action when public_reason is true" do
    result =
      tool(topic_id: topic.id, unlisted: true, reason: "Needs cleanup", public_reason: true).invoke

    expect(result[:status]).to eq("success")
    small_action = topic.ordered_posts.last
    expect(small_action.post_type).to eq(Post.types[:small_action])
    expect(small_action.raw).to eq("Needs cleanup")
  end

  it "does not post the reason when public_reason is false" do
    result =
      tool(topic_id: topic.id, unlisted: true, reason: "Needs cleanup", public_reason: false).invoke

    expect(result[:status]).to eq("success")
    small_action = topic.ordered_posts.last
    expect(small_action.raw).to be_blank
  end

  it "returns an error when topic is not found" do
    result = tool(topic_id: -1, unlisted: true, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(topic_id: topic.id, unlisted: true, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Personas::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { topic_id: topic.id, unlisted: true, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
