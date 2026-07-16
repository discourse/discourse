# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ChangeSiteSetting do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:context) { DiscourseAi::Agents::BotContext.new }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  it "changes the setting and logs a staff action" do
    result = tool(setting_name: "min_post_length", value: "42", reason: "Testing").invoke

    expect(result[:status]).to eq("success")
    expect(SiteSetting.min_post_length).to eq(42)
    expect(
      UserHistory.where(
        action: UserHistory.actions[:change_site_setting],
        subject: "min_post_length",
      ).count,
    ).to eq(1)
  end

  it "coerces boolean values from strings" do
    result = tool(setting_name: "enable_badges", value: "false", reason: "Testing").invoke

    expect(result[:status]).to eq("success")
    expect(SiteSetting.enable_badges).to eq(false)
  end

  it "returns an error when reason is blank" do
    result = tool(setting_name: "min_post_length", value: "42", reason: " ").invoke

    expect(result[:status]).to eq("error")
    expect(SiteSetting.min_post_length).not_to eq(42)
  end

  it "returns an error for an unknown setting" do
    result = tool(setting_name: "definitely_not_a_setting", value: "42", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("definitely_not_a_setting")
  end

  it "returns an error for a hidden setting" do
    hidden_setting = SiteSetting.hidden_settings.first

    result = tool(setting_name: hidden_setting.to_s, value: "x", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("hidden")
  end

  it "points at the replacement for a hard-deprecated setting" do
    old_name, new_name, _override, _version =
      SiteSettings::DeprecatedSettings::SETTINGS.find { |_, _, override, _| !override }
    skip "no hard-deprecated settings to test with" if old_name.nil?

    result = tool(setting_name: old_name, value: "x", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include(new_name)
  end

  it "returns an error for an invalid value" do
    result = tool(setting_name: "default_locale", value: "zz_INVALID", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(SiteSetting.default_locale).not_to eq("zz_INVALID")
  end

  it "does not update upload-backed settings" do
    result =
      tool(setting_name: "logo", value: "https://example.com/logo.png", reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when the acting user is not an admin" do
    regular_user = Fabricate(:user)
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { setting_name: "min_post_length", value: "42", reason: "Test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )

    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
    expect(SiteSetting.min_post_length).not_to eq(42)
  end

  describe "#validation_error" do
    it "returns nil for a valid request without changing the setting" do
      t = tool(setting_name: "min_post_length", value: "42", reason: "Test")

      expect(t.validation_error).to be_nil
      expect(SiteSetting.min_post_length).not_to eq(42)
    end

    it "returns an error for an unknown setting and for an out-of-range value" do
      expect(
        tool(setting_name: "definitely_not_a_setting", value: "1", reason: "Test").validation_error[
          :status
        ],
      ).to eq("error")
      expect(
        tool(setting_name: "min_post_length", value: "0", reason: "Test").validation_error[:status],
      ).to eq("error")
    end
  end
end
