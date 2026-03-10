# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::MovePosts do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:topic)
  fab!(:post1, :post) { Fabricate(:post, topic: topic) }
  fab!(:post2, :post) { Fabricate(:post, topic: topic) }
  fab!(:destination_topic, :topic)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Agents::BotContext.new }

  it "moves posts to an existing topic" do
    result =
      tool(
        topic_id: topic.id,
        post_ids: [post2.id],
        destination_topic_id: destination_topic.id,
        reason: "Off-topic posts",
      ).invoke

    expect(result[:status]).to eq("success")
    expect(result[:destination_topic_id]).to eq(destination_topic.id)
    expect(post2.reload.topic_id).to eq(destination_topic.id)
  end

  it "moves posts to a new topic" do
    result =
      tool(
        topic_id: topic.id,
        post_ids: [post2.id],
        new_title: "Split discussion about something else",
        reason: "Splitting off-topic discussion",
      ).invoke

    expect(result[:status]).to eq("success")
    expect(result[:destination_topic_id]).to be_present
    expect(post2.reload.topic_id).to eq(result[:destination_topic_id])
  end

  it "returns an error when neither destination_topic_id nor new_title is provided" do
    result = tool(topic_id: topic.id, post_ids: [post2.id], reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when topic is not found" do
    result =
      tool(
        topic_id: -1,
        post_ids: [post2.id],
        destination_topic_id: destination_topic.id,
        reason: "Test",
      ).invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when post_ids is empty" do
    result =
      tool(
        topic_id: topic.id,
        post_ids: [],
        destination_topic_id: destination_topic.id,
        reason: "Test",
      ).invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result =
      tool(
        topic_id: topic.id,
        post_ids: [post2.id],
        destination_topic_id: destination_topic.id,
        reason: " ",
      ).invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        {
          topic_id: topic.id,
          post_ids: [post2.id],
          destination_topic_id: destination_topic.id,
          reason: "test",
        },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
