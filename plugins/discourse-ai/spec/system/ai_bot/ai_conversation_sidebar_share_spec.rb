# frozen_string_literal: true

RSpec.describe "AI Bot conversation sidebar share" do
  fab!(:admin) { Fabricate(:admin, username: "ai_sharer") }
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:agent) do
    Fabricate(:ai_agent, name: "Sidebar Agent", default_llm: gpt_4).tap(&:ensure_user!)
  end
  let(:bot_user) { agent.user }

  let(:pm) do
    Fabricate(
      :private_message_topic,
      title: "Shareable AI conversation",
      user: admin,
      last_posted_at: 1.minute.ago,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: admin),
        Fabricate.build(:topic_allowed_user, user: bot_user),
      ],
    )
  end

  let(:ai_pm_homepage) { PageObjects::Components::AiPmHomepage.new }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_public_sharing_allowed_groups = "1" # admins
    SiteSetting.navigation_menu = "sidebar"
    toggle_enabled_bots(bots: [gpt_4])
    Group.refresh_automatic_groups!

    pm.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
    pm.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD] = agent.id
    pm.custom_fields[DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD] = gpt_4.id
    pm.save_custom_fields
    Fabricate(:post, topic: pm, user: admin, raw: "How do I do stuff?")
    Fabricate(:post, topic: pm, user: bot_user, raw: "Here is how you do stuff")

    sign_in(admin)
  end

  it "shows Share in the conversation menu" do
    page.visit(Topic.relative_url(pm.id, pm.slug))

    ai_pm_homepage.open_conversation_menu(pm)

    expect(ai_pm_homepage).to have_share_conversation_menu_item
    expect(ai_pm_homepage).to have_star_conversation_menu_item
  end

  it "opens the share modal from the conversation menu" do
    page.visit(Topic.relative_url(pm.id, pm.slug))

    ai_pm_homepage.share_conversation(pm)

    expect(page).to have_css(".ai-share-full-topic-modal")
  end
end
