# frozen_string_literal: true

RSpec.describe "Shortcuts | mark all read", type: :system, js: true do
  fab!(:user_1) { Fabricate(:admin) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:channel_2) { Fabricate(:chat_channel) }
  fab!(:channel_3) { Fabricate(:chat_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:drawer) { PageObjects::Pages::ChatDrawer.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap(user_1, [channel_1, channel_2, channel_3])
    sign_in(user_1)
    Fabricate(:chat_message, chat_channel: channel_1)
    Fabricate(:chat_message, chat_channel: channel_1)
    Fabricate(:chat_message, chat_channel: channel_2)
    Fabricate(:chat_message, chat_channel: channel_2)
  end

  context "when chat is open" do
    before { visit(channel_3.url) }

    context "when pressing shift+esc" do
      it "marks all channels read" do
        pause_test
        expect(page).to have_css(
          ".sidebar-section-link.channel-#{channel_1.id} .sidebar-section-link-suffix.unread",
        )
        expect(page).to have_css(
          ".sidebar-section-link.channel-#{channel_2.id} .sidebar-section-link-suffix.unread",
        )
        find("body").send_keys(%i[shift escape])
        expect(page).not_to have_css(
          ".sidebar-section-link.channel-#{channel_1.id} .sidebar-section-link-suffix.unread",
        )
        expect(page).not_to have_css(
          ".sidebar-section-link.channel-#{channel_2.id} .sidebar-section-link-suffix.unread",
        )
      end
    end
  end
end
