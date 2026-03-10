# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::EditTags do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:post)
  fab!(:tag1, :tag) { Fabricate(:tag, name: "alpha") }
  fab!(:tag2, :tag) { Fabricate(:tag, name: "beta") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.tagging_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Personas::BotContext.new }
  let(:topic) { post.topic }

  it "sets tags on the topic" do
    result = tool(topic_id: topic.id, tags: %w[alpha beta], reason: "Adding relevant tags").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.tags.pluck(:name)).to contain_exactly("alpha", "beta")
  end

  it "appends to existing tags by default" do
    topic.tags << tag1

    result = tool(topic_id: topic.id, tags: %w[beta], reason: "Adding tag").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.tags.pluck(:name)).to contain_exactly("alpha", "beta")
  end

  it "replaces existing tags when replace is true" do
    topic.tags << tag1

    result = tool(topic_id: topic.id, tags: %w[beta], reason: "Retagging", replace: true).invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.tags.pluck(:name)).to contain_exactly("beta")
  end

  it "sets a public edit reason when public_edit_reason is true" do
    result =
      tool(
        topic_id: topic.id,
        tags: %w[alpha],
        reason: "Categorizing",
        public_edit_reason: true,
      ).invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.edit_reason).to eq("Categorizing")
  end

  it "does not set a public edit reason by default" do
    result = tool(topic_id: topic.id, tags: %w[alpha], reason: "Categorizing").invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.edit_reason).to be_nil
  end

  it "returns an error when topic is not found" do
    result = tool(topic_id: -1, tags: %w[alpha], reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(topic_id: topic.id, tags: %w[alpha], reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when tagging is disabled" do
    SiteSetting.tagging_enabled = false

    result = tool(topic_id: topic.id, tags: %w[alpha], reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Personas::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { topic_id: topic.id, tags: %w[alpha], reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
