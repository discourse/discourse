# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::GrantBadge do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:user)
  fab!(:badge) { Fabricate(:badge, name: "Helpful Member") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Personas::BotContext.new }

  it "grants the badge to the user" do
    result =
      tool(
        username: user.username,
        badge_name: "Helpful Member",
        reason: "Consistently helpful",
      ).invoke

    expect(result[:status]).to eq("success")
    expect(UserBadge.exists?(user: user, badge: badge)).to eq(true)
  end

  it "returns an error when user is not found" do
    result = tool(username: "nonexistent", badge_name: "Helpful Member", reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when badge is not found" do
    result = tool(username: user.username, badge_name: "Nonexistent Badge", reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when badge is disabled" do
    badge.update!(enabled: false)

    result = tool(username: user.username, badge_name: "Helpful Member", reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(username: user.username, badge_name: "Helpful Member", reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Personas::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { username: user.username, badge_name: badge.name, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
