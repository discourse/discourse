# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ReadSiteSetting do
  fab!(:llm_model)

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(setting_name, context: DiscourseAi::Agents::BotContext.new)
    described_class.new(
      { setting_name: setting_name },
      bot_user: bot_user,
      llm: llm,
      context: context,
    )
  end

  it "returns the current value for an administrator" do
    SiteSetting.min_post_length = 42

    expect(tool("min_post_length").invoke).to eq(setting_name: "min_post_length", value: 42)
  end

  it "returns an error when the acting user is not an administrator" do
    context = DiscourseAi::Agents::BotContext.new(user: Fabricate(:user))

    result = tool("min_post_length", context: context).invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end

  it "returns an error for an unknown setting" do
    result = tool("definitely_not_a_setting").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("definitely_not_a_setting")
  end

  it "does not return hidden or secret setting values" do
    hidden_setting = SiteSetting.hidden_settings.first
    secret_setting = SiteSetting.secret_settings.first

    expect(tool(hidden_setting).invoke[:status]).to eq("error")
    expect(tool(secret_setting).invoke[:status]).to eq("error")
  end
end
