# frozen_string_literal: true
RSpec.describe "Share conversation", type: :system do
  fab!(:admin) { Fabricate(:admin, username: "ai_sharer") }
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-4") }

  let(:pm) do
    Fabricate(
      :private_message_topic,
      title: "This is my special PM",
      user: admin,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: admin),
        Fabricate.build(:topic_allowed_user, user: bot_user),
      ],
    )
  end

  let(:pm_posts) do
    posts = []
    i = 1
    3.times do
      posts << Fabricate(:post, topic: pm, user: admin, raw: "test test test user reply #{i}")
      posts << Fabricate(:post, topic: pm, user: bot_user, raw: "test test test bot reply #{i}")
      i += 1
    end

    posts
  end

  let(:cdp) { PageObjects::CDP.new }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_4])
    sign_in(admin)

    bot_user.update!(username: "gpt-4")

    Group.refresh_automatic_groups!

    cdp.allow_clipboard
    page.execute_script("window.navigator.clipboard.writeText('')")
  end

  it "can share a conversation with a persona user" do
    clip_text = nil

    persona = Fabricate(:ai_persona, name: "Tester")
    persona.create_user!

    Fabricate(:post, topic: pm, user: admin, raw: "How do I do stuff?")
    Fabricate(:post, topic: pm, user: persona.user, raw: "No idea")

    visit(pm.url)

    find("#post_2 .post-action-menu__share-ai").click

    try_until_success do
      clip_text = cdp.read_clipboard
      expect(clip_text).not_to eq("")
    end

    conversation = (<<~TEXT).strip
      <details class='ai-quote'>
      <summary>
      <span>This is my special PM</span>
      <span title='Conversation with AI'>AI</span>
      </summary>

      **ai_sharer:**

      How do I do stuff?

      **Tester_bot:**

      No idea
      </details>
    TEXT

    expect(conversation).to eq(clip_text)
  end

  it "can share a conversation" do
    clip_text = nil

    pm
    pm_posts

    visit(pm.url)

    find("#post_2 .post-action-menu__share-ai").click

    try_until_success do
      clip_text = cdp.read_clipboard
      expect(clip_text).not_to eq("")
    end

    conversation = (<<~TEXT).strip
      <details class='ai-quote'>
      <summary>
      <span>This is my special PM</span>
      <span title='Conversation with AI'>AI</span>
      </summary>

      **ai_sharer:**

      test test test user reply 1

      **gpt-4:**

      test test test bot reply 1
      </details>
    TEXT

    expect(conversation).to eq(clip_text)

    page.execute_script("window.navigator.clipboard.writeText('')")

    find("#post_6 .post-action-menu__share-ai").click
    find(".ai-share-modal__slider input").set("2")
    find(".ai-share-modal button.btn-primary").click

    try_until_success do
      clip_text = cdp.read_clipboard
      expect(clip_text).not_to eq("")
    end

    conversation = (<<~TEXT).strip
      <details class='ai-quote'>
      <summary>
      <span>This is my special PM</span>
      <span title='Conversation with AI'>AI</span>
      </summary>

      **ai_sharer:**

      test test test user reply 2

      **gpt-4:**

      test test test bot reply 2

      **ai_sharer:**

      test test test user reply 3

      **gpt-4:**

      test test test bot reply 3
      </details>
    TEXT

    expect(conversation).to eq(clip_text)
  end
end
