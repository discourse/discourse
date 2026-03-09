# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::LockPost do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:post)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Personas::BotContext.new }

  it "locks the post when locked is true" do
    result = tool(post_id: post.id, locked: true, reason: "Preventing edits").invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.locked_by_id).to eq((bot_user || Discourse.system_user).id)
  end

  it "unlocks the post when locked is false" do
    post.update!(locked_by_id: Discourse.system_user.id)

    result = tool(post_id: post.id, locked: false, reason: "Allowing edits again").invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.locked_by_id).to be_nil
  end

  it "returns an error when post is not found" do
    result = tool(post_id: -1, locked: true, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(post_id: post.id, locked: true, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Personas::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { post_id: post.id, locked: true, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
