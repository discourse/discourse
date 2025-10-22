#frozen_string_literal: true

describe DiscourseAi::AiBot::SiteSettingsExtension do
  fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:gpt_35_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }

  def user_exists?(model)
    DiscourseAi::AiBot::EntryPoint.find_user_from_model(model).present?
  end

  before { enable_current_plugin }

  it "correctly creates/deletes bot accounts as needed" do
    SiteSetting.ai_bot_enabled = true
    gpt_4.update!(enabled_chat_bot: true)
    claude_2.update!(enabled_chat_bot: false)
    gpt_35_turbo.update!(enabled_chat_bot: false)

    DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots

    expect(user_exists?("gpt-4")).to eq(true)
    expect(user_exists?("gpt-3.5-turbo")).to eq(false)
    expect(user_exists?("claude-2")).to eq(false)

    gpt_4.update!(enabled_chat_bot: false)
    claude_2.update!(enabled_chat_bot: false)
    gpt_35_turbo.update!(enabled_chat_bot: true)

    DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots

    expect(user_exists?("gpt-4")).to eq(false)
    expect(user_exists?("gpt-3.5-turbo")).to eq(true)
    expect(user_exists?("claude-2")).to eq(false)

    gpt_4.update!(enabled_chat_bot: false)
    claude_2.update!(enabled_chat_bot: true)
    gpt_35_turbo.update!(enabled_chat_bot: true)

    DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots

    expect(user_exists?("gpt-4")).to eq(false)
    expect(user_exists?("gpt-3.5-turbo")).to eq(true)
    expect(user_exists?("claude-2")).to eq(true)

    SiteSetting.ai_bot_enabled = false
    DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots

    expect(user_exists?("gpt-4")).to eq(false)
    expect(user_exists?("gpt-3.5-turbo")).to eq(false)
    expect(user_exists?("claude-2")).to eq(false)
  end

  it "leaves accounts around if they have any posts" do
    SiteSetting.ai_bot_enabled = true
    gpt_4.update!(enabled_chat_bot: true)
    DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots

    user = DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-4")

    create_post(user: user, raw: "this is a test post")

    user.reload
    SiteSetting.ai_bot_enabled = false

    user.reload
    expect(user.active).to eq(false)

    SiteSetting.ai_bot_enabled = true

    user.reload
    expect(user.active).to eq(true)
  end
end
