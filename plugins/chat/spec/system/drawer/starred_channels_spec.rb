# frozen_string_literal: true

RSpec.describe "Drawer - starred channels", type: :system do
  fab!(:current_user, :user)
  fab!(:channel_1) { Fabricate(:category_channel, name: "Channel A") }
  fab!(:channel_2) { Fabricate(:category_channel, name: "Channel B") }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    channel_2.add(current_user)
    sign_in(current_user)
    chat_page.prefers_drawer
  end

  context "when user has starred channels" do
    before { channel_1.membership_for(current_user).update!(starred: true) }

    it "defaults to starred channels, shows footer tab, and can open channel" do
      visit("/")
      chat_page.open_from_header

      expect(drawer_page).to have_open_starred_channels
      expect(page).to have_css("#c-footer-starred.--active")

      find(".chat-channel-row[data-chat-channel-id='#{channel_1.id}']").click
      expect(drawer_page).to have_open_channel(channel_1)
    end
  end

  context "when user has no starred channels" do
    it "does not show starred tab in footer" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_no_css("#c-footer-starred")
    end
  end

  context "when user has starred both channels and DMs" do
    fab!(:user_1) { Fabricate(:user, username: "alice") }
    fab!(:user_2) { Fabricate(:user, username: "bob") }
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [current_user, user_2]) }

    before do
      channel_1.membership_for(current_user).update!(starred: true)
      channel_2.membership_for(current_user).update!(starred: true)
      dm_channel_1.membership_for(current_user).update!(starred: true)
      dm_channel_2.membership_for(current_user).update!(starred: true)
    end

    it "sorts by unreads first, then public channels before DMs" do
      Fabricate(:chat_message, chat_channel: channel_2, user: user_1)
      Fabricate(:chat_message, chat_channel: dm_channel_1, user: user_1)
      channel_2.membership_for(current_user).update!(last_viewed_at: 1.minute.ago)
      dm_channel_1.membership_for(current_user).update!(last_viewed_at: 1.minute.ago)

      visit("/")
      chat_page.open_from_header
      drawer_page.click_starred_channels

      channels = page.all(".chat-channel-row")
      expect(channels.map { |c| c["data-chat-channel-id"] }).to eq(
        [channel_2.id, channel_1.id, dm_channel_1.id, dm_channel_2.id].map(&:to_s),
      )
    end
  end

  context "when navigating back from a channel" do
    before { channel_1.membership_for(current_user).update!(starred: true) }

    it "returns to starred channels when starred channels exist" do
      visit("/")
      chat_page.open_from_header
      drawer_page.click_starred_channels
      find(".chat-channel-row[data-chat-channel-id='#{channel_1.id}']").click

      find(".c-navbar__back-button").click
      expect(drawer_page).to have_open_starred_channels
    end

    it "redirects to channels list after unstarring the last channel" do
      visit("/")
      chat_page.open_from_header
      drawer_page.click_starred_channels
      find(".chat-channel-row[data-chat-channel-id='#{channel_1.id}']").click

      find(".c-navbar__star-channel-button").click
      expect(page).to have_no_css(".c-navbar__star-channel-button.--starred")

      find(".c-navbar__back-button").click
      expect(drawer_page).to have_open_channels
    end
  end
end
