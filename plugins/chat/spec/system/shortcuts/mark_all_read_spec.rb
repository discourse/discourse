# frozen_string_literal: true

RSpec.describe "Shortcuts | mark all read" do
  fab!(:user_1, :admin)
  fab!(:author, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:channel_2, :chat_channel)
  fab!(:channel_3, :chat_channel)

  let(:chat_sidebar) { PageObjects::Pages::ChatSidebar.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer) { PageObjects::Pages::ChatDrawer.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap(user_1, [channel_1, channel_2, channel_3])
    sign_in(user_1)
    [channel_1, channel_2].each do |channel|
      Fabricate.times(2, :chat_message, chat_channel: channel, user: author)
      channel.update_last_message_id!
    end
  end

  context "when chat is open" do
    before { visit(channel_3.url) }

    context "when pressing shift+esc" do
      it "marks all channels read" do
        expect(page).to have_css(
          ".sidebar-section-link.channel-#{channel_1.id} .sidebar-section-link-content-badge.unread",
        )
        expect(page).to have_css(
          ".sidebar-section-link.channel-#{channel_2.id} .sidebar-section-link-content-badge.unread",
        )
        find("body").send_keys(%i[shift escape])
        [channel_1, channel_2].each do |channel|
          expect(find(".sidebar-section-link.channel-#{channel.id}")).to have_no_css(
            ".sidebar-section-link-content-badge.unread",
          )
        end
        chat_sidebar.open_channel(channel_2)
        expect(channel_page.messages).to have_message(id: channel_2.chat_messages.last.id)
        expect(page).not_to have_content(I18n.t("js.chat.last_visit"))
      end
    end
  end
end
