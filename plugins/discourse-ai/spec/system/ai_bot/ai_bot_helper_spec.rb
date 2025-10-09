# frozen_string_literal: true
RSpec.describe "AI chat channel summarization", type: :system do
  fab!(:user)
  fab!(:group) { Fabricate(:group, visibility_level: Group.visibility_levels[:staff]) }

  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:gpt_3_5_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_add_to_header = true
    toggle_enabled_bots(bots: [gpt_4, gpt_3_5_turbo])
    SiteSetting.ai_bot_allowed_groups = group.id.to_s
    sign_in(user)
  end

  it "does not show AI button to users not in group" do
    visit "/latest"
    expect(page).not_to have_selector(".ai-bot-button")
  end
end
