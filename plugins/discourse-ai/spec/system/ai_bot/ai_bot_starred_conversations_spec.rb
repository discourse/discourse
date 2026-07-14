# frozen_string_literal: true

RSpec.describe "AI Bot starred conversations" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:bot_user) do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_4])
    gpt_4.reload.user
  end

  fab!(:starred_pm) do
    Fabricate(
      :private_message_topic,
      title: "Already starred AI conversation",
      user: user,
      recipient: bot_user,
      last_posted_at: 2.minutes.ago,
    )
  end
  fab!(:unstarred_pm) do
    Fabricate(
      :private_message_topic,
      title: "Unstarred AI conversation",
      user: user,
      recipient: bot_user,
      last_posted_at: 1.minute.ago,
    )
  end

  let(:ai_pm_homepage) { PageObjects::Components::AiPmHomepage.new }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.enable_ai_bot_starred_conversations = true
    SiteSetting.navigation_menu = "sidebar"
    toggle_enabled_bots(bots: [gpt_4])

    mark_ai_bot_pm(starred_pm)
    mark_ai_bot_pm(unstarred_pm)

    Fabricate(:post, topic: starred_pm, user: user, raw: "hello starred")
    Fabricate(:post, topic: unstarred_pm, user: user, raw: "hello unstarred")

    sign_in(user)
  end

  it "shows starred conversations in a Starred section and removes them from date sections" do
    DiscourseAi::AiBot::ConversationStar.create!(user: user, topic: starred_pm)

    page.visit(Topic.relative_url(unstarred_pm.id, unstarred_pm.slug))

    expect(ai_pm_homepage).to have_starred_conversations_section
    expect(ai_pm_homepage.starred_section).to have_css(".ai-conversation-#{starred_pm.id}")
    expect(ai_pm_homepage.today_section).to have_no_css(".ai-conversation-#{starred_pm.id}")
    expect(ai_pm_homepage.today_section).to have_css(".ai-conversation-#{unstarred_pm.id}")
  end

  it "stars a conversation from the sidebar menu and moves it live" do
    page.visit(Topic.relative_url(unstarred_pm.id, unstarred_pm.slug))

    expect(ai_pm_homepage).to have_no_starred_conversations_section
    expect(ai_pm_homepage.today_section).to have_css(".ai-conversation-#{unstarred_pm.id}")

    ai_pm_homepage.toggle_star_for_conversation(unstarred_pm)

    expect(ai_pm_homepage).to have_starred_conversations_section
    expect(ai_pm_homepage.starred_section).to have_css(".ai-conversation-#{unstarred_pm.id}")
    expect(ai_pm_homepage.today_section).to have_no_css(".ai-conversation-#{unstarred_pm.id}")
    expect(DiscourseAi::AiBot::ConversationStar.exists?(user: user, topic: unstarred_pm)).to eq(
      true,
    )
  end

  def mark_ai_bot_pm(topic)
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
    topic.save!
  end
end
