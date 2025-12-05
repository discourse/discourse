# frozen_string_literal: true

RSpec.describe "Drawer - starred channels", type: :system do
  fab!(:current_user, :user)
  fab!(:channel_1) { Fabricate(:category_channel, name: "Channel A") }
  fab!(:channel_2) { Fabricate(:category_channel, name: "Channel B") }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    SiteSetting.star_chat_channels = true
    channel_1.add(current_user)
    channel_2.add(current_user)
    sign_in(current_user)
    chat_page.prefers_drawer
  end

  context "when user has starred channels" do
    before { channel_1.membership_for(current_user).update!(starred: true) }

    it "shows starred tab in footer" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_css("#c-footer-starred")
    end

    it "navigates to starred channels when clicking footer tab" do
      visit("/")
      chat_page.open_from_header
      drawer_page.click_starred_channels

      expect(drawer_page).to have_open_starred_channels
      expect(page).to have_css("#c-footer-starred.--active")
    end

    it "shows the starred channel in the list" do
      visit("/")
      chat_page.open_from_header
      drawer_page.click_starred_channels

      expect(page).to have_css(".chat-channel-row[data-chat-channel-id='#{channel_1.id}']")
    end

    it "can open a starred channel" do
      visit("/")
      chat_page.open_from_header
      drawer_page.click_starred_channels
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

  context "when star_chat_channels setting is disabled" do
    before do
      channel_1.membership_for(current_user).update!(starred: true)
      SiteSetting.star_chat_channels = false
    end

    it "does not show starred tab in footer" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_no_css("#c-footer-starred")
    end
  end

  context "when user has starred both channels and DMs" do
    fab!(:user_1, :user)
    fab!(:user_2, :user)
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [current_user, user_2]) }

    before do
      user_1.update!(username: "alice")
      user_2.update!(username: "bob")
      channel_1.membership_for(current_user).update!(starred: true)
      channel_2.membership_for(current_user).update!(starred: true)
      dm_channel_1.membership_for(current_user).update!(starred: true)
      dm_channel_2.membership_for(current_user).update!(starred: true)
    end

    it "shows regular channels before DMs in the starred channels list" do
      visit("/")
      chat_page.open_from_header
      drawer_page.click_starred_channels

      channels = page.all(".chat-channel-row")
      expect(channels[0]["data-chat-channel-id"]).to eq(channel_1.id.to_s)
      expect(channels[1]["data-chat-channel-id"]).to eq(channel_2.id.to_s)
      expect(channels[2]["data-chat-channel-id"]).to eq(dm_channel_1.id.to_s)
      expect(channels[3]["data-chat-channel-id"]).to eq(dm_channel_2.id.to_s)
    end

    it "shows regular channels with unreads before DMs with unreads" do
      Fabricate(:chat_message, chat_channel: channel_2, user: user_1)
      Fabricate(:chat_message, chat_channel: dm_channel_1, user: user_1)
      channel_2.membership_for(current_user).update!(last_viewed_at: 1.minute.ago)
      dm_channel_1.membership_for(current_user).update!(last_viewed_at: 1.minute.ago)

      visit("/")
      chat_page.open_from_header
      drawer_page.click_starred_channels

      channels = page.all(".chat-channel-row")
      expect(channels[0]["data-chat-channel-id"]).to eq(channel_2.id.to_s)
      expect(channels[1]["data-chat-channel-id"]).to eq(channel_1.id.to_s)
      expect(channels[2]["data-chat-channel-id"]).to eq(dm_channel_1.id.to_s)
      expect(channels[3]["data-chat-channel-id"]).to eq(dm_channel_2.id.to_s)
    end
  end
end
