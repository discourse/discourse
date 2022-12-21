# frozen_string_literal: true

RSpec.describe "Unfollow dm channel", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, other_user]) }

  let!(:chat_page) { PageObjects::Pages::Chat.new }
  let!(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
    sign_in(current_user)
  end

  def create_message(text: "this is fine", channel:, creator: Fabricate(:user))
    using_session(creator.username) do
      sign_in(creator)
      chat_page.visit_channel(channel)
      chat_channel_page.send_message(text)
      expect(chat_channel_page).to have_message(text: text)
    end
  end

  context "when receiving a message after unfollowing" do
    it "correctly shows the channel" do
      find(".channel-#{dm_channel_1.id}").hover
      find(".channel-#{dm_channel_1.id} .sidebar-section-link-hover").click

      expect(page).to have_no_css(".channel-#{dm_channel_1.id}")

      create_message(channel: dm_channel_1, creator: other_user)

      expect(page).to have_css(".channel-#{dm_channel_1.id} .urgent")
    end
  end
end
