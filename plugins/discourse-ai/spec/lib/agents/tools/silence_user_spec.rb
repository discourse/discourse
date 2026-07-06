# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::SilenceUser do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:user)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Agents::BotContext.new }

  it "silences the user" do
    result =
      tool(username: user.username, duration_days: 7, reason: "Repeated off-topic posts").invoke

    expect(result[:status]).to eq("success")
    expect(user.reload.silenced?).to eq(true)
  end

  it "returns an error when user is not found" do
    result = tool(username: "nonexistent", duration_days: 7, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(username: user.username, duration_days: 7, reason: " ").invoke

    expect(result[:status]).to eq("error")
    expect(user.reload.silenced?).to eq(false)
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { username: user.username, duration_days: 7, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
    expect(user.reload.silenced?).to eq(false)
  end

  it "returns an error when the user is already silenced" do
    UserSilencer.new(user, Discourse.system_user, reason: "Prior offense").silence

    result = tool(username: user.username, duration_days: 7, reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("already silenced")
  end

  it "returns an error and does not silence when duration_days is zero" do
    result = tool(username: user.username, duration_days: 0, reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(user.reload.silenced?).to eq(false)
  end

  it "returns an error and does not silence when duration_days is negative" do
    result = tool(username: user.username, duration_days: -5, reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(user.reload.silenced?).to eq(false)
  end

  it "returns an error and does not silence when duration_days is not numeric" do
    result = tool(username: user.username, duration_days: "soon", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(user.reload.silenced?).to eq(false)
  end
end
