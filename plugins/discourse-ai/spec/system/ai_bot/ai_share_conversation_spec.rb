# frozen_string_literal: true

RSpec.describe "Share conversation via link", type: :system do
  fab!(:admin) { Fabricate(:admin, username: "ai_sharer") }
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_4])
    SiteSetting.ai_bot_public_sharing_allowed_groups = "1" # admin
    Group.refresh_automatic_groups!
    sign_in(admin)
  end

  let(:pm) do
    Fabricate(
      :private_message_topic,
      title: "This is my special PM",
      user: admin,
      topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: admin)],
    )
  end

  let!(:op) { Fabricate(:post, topic: pm, user: admin, raw: "test test test user reply") }

  it "does not show share button for my own PMs without bot" do
    visit(pm.url)
    expect(Guardian.new(admin).can_share_ai_bot_conversation?(pm)).to eq(false)
    expect(page).not_to have_selector(".share-ai-conversation-button")
  end
end
