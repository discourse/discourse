# frozen_string_literal: true

RSpec.describe "AI Bot docked composer" do
  let(:topic_page) { PageObjects::Pages::Topic.new }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  fab!(:claude_2) do
    Fabricate(
      :llm_model,
      provider: "anthropic",
      url: "https://api.anthropic.com/v1/messages",
      name: "claude-2",
      display_name: "Claude 2",
    )
  end

  fab!(:bot_user) do
    enable_current_plugin
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.ai_bot_enabled = true
    claude_2.reload.user
  end

  fab!(:pm) do
    Fabricate(
      :private_message_topic,
      title: "A bot conversation",
      user: user,
      last_posted_at: Time.zone.now,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: user),
        Fabricate.build(:topic_allowed_user, user: bot_user),
      ],
    )
  end

  fab!(:first_post) { Fabricate(:post, topic: pm, user: user, post_number: 1, raw: "Hello bot") }
  fab!(:bot_post) { Fabricate(:post, topic: pm, user: bot_user, post_number: 2, raw: "Hello user") }

  fab!(:regular_topic) { Fabricate(:topic, user: user) }
  fab!(:regular_post) { Fabricate(:post, topic: regular_topic, user: user, raw: "Regular topic") }

  before do
    enable_current_plugin
    pm.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
    pm.save!
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.ai_bot_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
    Jobs.run_immediately!
    sign_in(user)
  end

  it "renders the docked composer on an AI bot PM and hides the popup reply UI" do
    topic_page.visit_topic(pm)

    expect(page).to have_css(".ai-bot-docked-composer")
    expect(page).to have_css(".ai-bot-docked-composer .d-editor-input")
    expect(page).to have_no_css("#topic-footer-buttons .create")
  end

  it "sends a reply via the docked composer when pressing Enter" do
    topic_page.visit_topic(pm)
    expect(page).to have_css(".ai-bot-docked-composer")

    DiscourseAi::Completions::Llm.with_prepared_responses(["Bot reply to docked message"]) do
      find(".ai-bot-docked-composer .d-editor-input").fill_in(
        with: "Message from the docked composer",
      )
      find(".ai-bot-docked-composer .d-editor-input").send_keys(:enter)

      expect(page).to have_content("Message from the docked composer")
    end
  end

  it "does not render the docked composer on regular topics" do
    topic_page.visit_topic(regular_topic)

    expect(page).to have_no_css(".ai-bot-docked-composer")
    expect(page).to have_css("#topic-footer-buttons .create")
  end

  it "cleans up when navigating from a bot PM to a regular topic" do
    topic_page.visit_topic(pm)
    expect(page).to have_css(".ai-bot-docked-composer")
    expect(page).to have_css("body.has-ai-bot-docked-composer")

    topic_page.visit_topic(regular_topic)

    expect(page).to have_no_css(".ai-bot-docked-composer")
    expect(page).to have_no_css("body.has-ai-bot-docked-composer")
    expect(page).to have_css("#topic-footer-buttons .create")
  end

  it "hides the toolbar by default and shows it when the toggle button is clicked" do
    topic_page.visit_topic(pm)

    expect(page).to have_css(".ai-bot-docked-composer.docked-composer--toolbar-hidden")
    expect(page).to have_no_css(".d-editor-button-bar__wrap", visible: true)

    find(".ai-bot-docked-composer__toolbar-toggle").click

    expect(page).to have_no_css(".ai-bot-docked-composer.docked-composer--toolbar-hidden")
  end

  it "clears the reply field after a successful submit" do
    topic_page.visit_topic(pm)

    DiscourseAi::Completions::Llm.with_prepared_responses(["Bot reply"]) do
      find(".ai-bot-docked-composer .d-editor-input").fill_in(with: "First message to the bot")
      find(".ai-bot-docked-composer .d-editor-input").send_keys(:enter)

      expect(page).to have_content("First message to the bot")
    end

    expect(find(".ai-bot-docked-composer .d-editor-input").value).to eq("")
  end
end
