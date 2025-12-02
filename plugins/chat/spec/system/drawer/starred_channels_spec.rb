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

    it "shows header with manage button" do
      visit("/")
      chat_page.open_from_header
      drawer_page.click_starred_channels

      expect(page).to have_css(".chat-channel-divider.starred-channels-section")
      expect(page).to have_css(".open-manage-starred-btn")
    end

    it "opens manage starred modal when clicking pencil button" do
      visit("/")
      chat_page.open_from_header
      drawer_page.click_starred_channels
      find(".open-manage-starred-btn").click

      expect(page).to have_css(".chat-modal-manage-starred-channels")
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
end
