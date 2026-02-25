# frozen_string_literal: true

RSpec.describe "Chat MessageBus | archive status", type: :system do
  fab!(:admin_1, :admin)
  fab!(:admin_2, :admin)
  fab!(:channel, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.chat_allow_archiving_channels = true
    chat_system_bootstrap(admin_1, [channel])
    chat_system_user_bootstrap(user: admin_2, channel: channel)
    Fabricate(:chat_message, chat_channel: channel)
  end

  it "second admin sees archive progress" do
    Jobs.run_immediately!

    sign_in(admin_2)
    chat_page.visit_channel(channel)

    using_session(:admin_1) do
      sign_in(admin_1)
      chat_page.visit_channel_settings(channel)
      click_button(I18n.t("js.chat.channel_settings.archive_channel"))
      find("#split-topic-name").fill_in(with: "Archived topic for testing")
      click_button(I18n.t("js.chat.channel_archive.title"))
      expect(page).to have_css(".chat-channel-archive-status", wait: 15)
    end

    expect(page).to have_css(".chat-channel-archive-status", wait: 15)
  end
end
