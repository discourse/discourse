# frozen_string_literal: true

RSpec.describe "Unfollow dm channel", type: :system do
  fab!(:current_user, :user)
  fab!(:other_user, :user)
  fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, other_user]) }

  let!(:chat_page) { PageObjects::Pages::Chat.new }
  let!(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when receiving a message after unfollowing" do
    it "correctly shows the channel" do
      visit("/")
      find(".channel-#{dm_channel_1.id}").hover
      find(".channel-#{dm_channel_1.id} .sidebar-section-link-hover").click

      expect(page).to have_no_css(".channel-#{dm_channel_1.id}")

      using_session(:user_1) do
        text = "this is fine"
        sign_in(other_user)
        chat_page.visit_channel(dm_channel_1)
        channel_page.send_message(text)
        expect(channel_page.messages).to have_message(text: text)
      end

      expect(page).to have_css(".channel-#{dm_channel_1.id} .urgent", wait: 25)
    end
  end
end
