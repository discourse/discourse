# frozen_string_literal: true

RSpec.describe "Shortcuts | mark all read", type: :system do
  fab!(:user_1) { Fabricate(:admin) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:channel_2) { Fabricate(:chat_channel) }
  fab!(:channel_3) { Fabricate(:chat_channel) }

  let(:chat_sidebar) { PageObjects::Pages::Sidebar.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer) { PageObjects::Pages::ChatDrawer.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap(user_1, [channel_1, channel_2, channel_3])
    sign_in(user_1)
    Fabricate(:chat_message, chat_channel: channel_1)
    Fabricate(:chat_message, chat_channel: channel_1)
    10.times do |i|
      Fabricate(:chat_message, chat_channel: channel_2, message: "all read message #{i}")
    end
  end

  context "when chat is open" do
    before { visit(channel_3.url) }

    context "when pressing shift+esc" do
      it "marks all channels read" do
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
        chat_sidebar.open_channel(channel_2)
        expect(page).to have_content("all read message 9")
        expect(page).not_to have_content(I18n.t("js.chat.last_visit"))
      end
    end
  end
end
