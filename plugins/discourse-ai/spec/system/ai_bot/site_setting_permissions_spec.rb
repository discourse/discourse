# frozen_string_literal: true

RSpec.describe "AI bot site setting permissions" do
  include ThemeScreenshotMarker

  fab!(:regular_user, :user)
  fab!(:moderator)
  fab!(:bot_agent) do
    agent = Fabricate(:ai_agent)
    agent.create_user!
    agent
  end
  fab!(:regular_user_channel) do
    Fabricate(:direct_message_channel, users: [regular_user, bot_agent.user])
  end
  fab!(:moderator_channel) do
    Fabricate(:direct_message_channel, users: [moderator, bot_agent.user])
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    enable_current_plugin
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    Group.refresh_automatic_groups!
  end

  def post_rejected_site_setting_request(channel:, user:)
    ChatSDK::Message.create(
      raw: "Change the site setting min_post_length to 42",
      channel_id: channel.id,
      guardian: Guardian.new(user),
    )

    ChatSDK::Message.create(
      raw:
        "**Change site setting**\n#{I18n.t("discourse_ai.ai_bot.change_site_setting.errors.not_allowed")}",
      channel_id: channel.id,
      guardian: Guardian.new(bot_agent.user),
    )
  end

  it "shows a regular user that they cannot change a site setting" do
    rejection =
      post_rejected_site_setting_request(channel: regular_user_channel, user: regular_user)

    sign_in(regular_user)
    chat_page.prefers_full_page
    chat_page.visit_channel(regular_user_channel)

    expect(chat_channel_page.messages).to have_message(
      id: rejection.id,
      text: I18n.t("discourse_ai.ai_bot.change_site_setting.errors.not_allowed"),
    )
    screenshot_marker(label: "ai-site-setting-permission-regular-user")
  end

  it "shows a moderator that they cannot request a site setting change" do
    rejection = post_rejected_site_setting_request(channel: moderator_channel, user: moderator)

    sign_in(moderator)
    chat_page.prefers_full_page
    chat_page.visit_channel(moderator_channel)

    expect(chat_channel_page.messages).to have_message(
      id: rejection.id,
      text: I18n.t("discourse_ai.ai_bot.change_site_setting.errors.not_allowed"),
    )
    screenshot_marker(label: "ai-site-setting-permission-moderator")
  end
end
