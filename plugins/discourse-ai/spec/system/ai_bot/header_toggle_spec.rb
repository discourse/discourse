# frozen_string_literal: true

RSpec.describe "AI Bot - Header Toggle", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:ai_pm_homepage) { PageObjects::Components::AiPmHomepage.new }
  let(:header) { PageObjects::Pages::DiscourseAi::Header.new }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:regular_topic, :topic)

  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:gpt_3_5_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_4, gpt_3_5_turbo])
    SiteSetting.ai_bot_allowed_groups = group.id.to_s
    SiteSetting.ai_bot_add_to_header = true
    SiteSetting.navigation_menu = "sidebar"

    group.add(user)
    group.save

    allowed_persona = AiPersona.last
    allowed_persona.update!(allowed_group_ids: [group.id], enabled: true)

    sign_in(user)
  end

  it "remembers the last forum URL and returns to it when toggling" do
    visit "/hot"

    header.click_bot_button
    expect(ai_pm_homepage).to have_homepage
    expect(header).to have_icon_in_bot_button(icon: "shuffle")

    header.click_bot_button
    expect(header).to have_icon_in_bot_button(icon: "robot")
    expect(page).to have_current_path("/hot")
  end

  it "updates stored forum URL when navigating between forum pages" do
    visit "/hot"

    header.click_bot_button
    expect(ai_pm_homepage).to have_homepage

    header.click_bot_button
    expect(header).to have_icon_in_bot_button(icon: "robot")
    expect(page).to have_current_path("/hot")

    visit "/categories"
    expect(page).to have_current_path("/categories")

    header.click_bot_button
    expect(ai_pm_homepage).to have_homepage

    header.click_bot_button
    expect(header).to have_icon_in_bot_button(icon: "robot")
    expect(page).to have_current_path("/categories")
  end
end
