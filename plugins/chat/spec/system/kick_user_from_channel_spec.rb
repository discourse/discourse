# frozen_string_literal: true

describe "Kick user from chat channel", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:channel_2) { Fabricate(:chat_channel) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
    sign_in(current_user)
    channel_1.add(current_user)
    channel_2.add(current_user)
  end

  def publish_kick
    Chat::Publisher.publish_kick_users(channel_1.id, [current_user.id])
  end

  context "when the user is looking at the channel they are kicked from" do
    before { chat.visit_channel(channel_1) }

    context "when the user presses ok" do
      it "redirects them to the first other public channel they have" do
        publish_kick
        dialog.click_yes
        expect(page).to have_current_path(channel_2.url)
      end

      context "when the user has no other public channels" do
        before do
          channel_2.remove(current_user)
          chat.visit_channel(channel_1)
        end

        it "redirects them to the chat browse page" do
          publish_kick
          dialog.click_yes
          expect(page).to have_current_path("/chat/browse/open")
        end
      end
    end
  end

  context "when the user is not looking at the channel they are kicked from" do
    before { chat.visit_channel(channel_2) }

    it "removes it from their sidebar and does not redirect" do
      publish_kick
      expect(sidebar_page.channels_section).not_to have_css(
        ".sidebar-section-link.channel-#{channel_1.id}",
      )
    end
  end
end
