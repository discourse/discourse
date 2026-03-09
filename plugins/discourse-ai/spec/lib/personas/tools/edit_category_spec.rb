# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::EditCategory do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:post)
  fab!(:category)
  fab!(:target_category, :category)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Personas::BotContext.new }

  it "moves the topic to a different category" do
    topic = post.topic
    topic.update!(category: category)

    result = tool(topic_id: topic.id, category_id: target_category.id, reason: "Better fit").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.category_id).to eq(target_category.id)
    expect(post.reload.edit_reason).to be_nil
  end

  it "sets a public edit reason when public_edit_reason is true" do
    topic = post.topic
    topic.update!(category: category)

    result =
      tool(
        topic_id: topic.id,
        category_id: target_category.id,
        reason: "Better fit",
        public_edit_reason: true,
      ).invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.edit_reason).to eq("Better fit")
  end

  it "returns an error when topic is not found" do
    result = tool(topic_id: -1, category_id: target_category.id, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when category is not found" do
    result = tool(topic_id: post.topic_id, category_id: -1, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(topic_id: post.topic_id, category_id: target_category.id, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Personas::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { topic_id: post.topic_id, category_id: target_category.id, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
