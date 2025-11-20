# frozen_string_literal: true

RSpec.describe "Pinned channels", type: :system do
  fab!(:current_user, :user)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:sidebar) { PageObjects::Pages::Sidebar.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    chat_system_bootstrap
    SiteSetting.navigation_menu = "sidebar"
    sign_in(current_user)
  end

  context "when pinning a channel" do
    fab!(:channel_1) { Fabricate(:category_channel, name: "Channel A") }

    before { channel_1.add(current_user) }

    it "shows the pinned channel at the top of the sidebar" do
      visit("/")

      chat_page.visit_channel_settings(channel_1)

      membership = channel_1.membership_for(current_user)

      expect {
        PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
        expect(toasts).to have_success(I18n.t("js.saved"))
      }.to change { membership.reload.pinned }.from(false).to(true)

      visit("/")

      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(1)")).to have_css(
        ".channel-#{channel_1.id}",
      )
    end

    it "shows a pin icon next to the pinned channel" do
      visit("/")

      chat_page.visit_channel_settings(channel_1)

      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      visit("/")

      expect(page.find(".sidebar-section-link.channel-#{channel_1.id}")).to have_css(
        ".sidebar-section-link-suffix.icon.pinned",
      )
    end
  end

  context "when pinning multiple channels" do
    fab!(:channel_1) { Fabricate(:category_channel, name: "Channel C") }
    fab!(:channel_2) { Fabricate(:category_channel, name: "Channel A") }
    fab!(:channel_3) { Fabricate(:category_channel, name: "Channel B") }

    before do
      channel_1.add(current_user)
      channel_2.add(current_user)
      channel_3.add(current_user)
    end

    it "sorts pinned channels alphabetically by slug" do
      visit("/")

      # Pin channel 1 (C)
      chat_page.visit_channel_settings(channel_1)
      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      # Pin channel 3 (B)
      chat_page.visit_channel_settings(channel_3)
      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      # Pin channel 2 (A)
      chat_page.visit_channel_settings(channel_2)
      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      visit("/")

      # Should be ordered: A, B, C (alphabetically by slug)
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(1)")).to have_css(
        ".channel-#{channel_2.id}",
      )
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(2)")).to have_css(
        ".channel-#{channel_3.id}",
      )
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(3)")).to have_css(
        ".channel-#{channel_1.id}",
      )
    end

    it "shows pinned channels above unpinned channels" do
      visit("/")

      # Pin only channel 1 (C)
      chat_page.visit_channel_settings(channel_1)
      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      visit("/")

      # Channel 1 (C - pinned) should be first, even though A and B come before it alphabetically
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(1)")).to have_css(
        ".channel-#{channel_1.id}",
      )
      # Unpinned channels should still be alphabetical
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(2)")).to have_css(
        ".channel-#{channel_2.id}",
      )
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(3)")).to have_css(
        ".channel-#{channel_3.id}",
      )
    end
  end

  context "when unpinning a channel" do
    fab!(:channel_1) { Fabricate(:category_channel, name: "Channel A") }
    fab!(:channel_2) { Fabricate(:category_channel, name: "Channel B") }

    before do
      channel_1.add(current_user)
      channel_2.add(current_user)

      # Pre-pin channel 1
      membership = channel_1.membership_for(current_user)
      membership.update!(pinned: true)
    end

    it "removes the channel from the pinned position" do
      visit("/")

      # Verify channel 1 is pinned and at the top
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(1)")).to have_css(
        ".channel-#{channel_1.id}",
      )

      chat_page.visit_channel_settings(channel_1)

      membership = channel_1.membership_for(current_user)

      expect {
        PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
        expect(toasts).to have_success(I18n.t("js.saved"))
      }.to change { membership.reload.pinned }.from(true).to(false)

      visit("/")

      # Now channels should be in alphabetical order
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(1)")).to have_css(
        ".channel-#{channel_1.id}",
      )
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(2)")).to have_css(
        ".channel-#{channel_2.id}",
      )
    end

    it "removes the pin icon from the unpinned channel" do
      visit("/")

      # Verify pin icon exists
      expect(page.find(".sidebar-section-link.channel-#{channel_1.id}")).to have_css(
        ".sidebar-section-link-suffix.icon.pinned",
      )

      chat_page.visit_channel_settings(channel_1)

      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      visit("/")

      # Verify pin icon is gone
      expect(page.find(".sidebar-section-link.channel-#{channel_1.id}")).to have_no_css(
        ".sidebar-section-link-suffix.icon.pinned",
      )
    end
  end

  context "when pinned channels with unread messages" do
    fab!(:channel_1) { Fabricate(:category_channel, name: "Channel A") }
    fab!(:channel_2) { Fabricate(:category_channel, name: "Channel B") }

    before do
      channel_1.add(current_user)
      channel_2.add(current_user)

      # Pin channel 2
      membership = channel_2.membership_for(current_user)
      membership.update!(pinned: true)
    end

    it "keeps pinned channels at the top even with unread messages in unpinned channels" do
      # Add unread message to unpinned channel
      Fabricate(:chat_message, chat_channel: channel_1)

      visit("/")

      # Pinned channel 2 should still be first, even though channel 1 has unread
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(1)")).to have_css(
        ".channel-#{channel_2.id}",
      )
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(2)")).to have_css(
        ".channel-#{channel_1.id}",
      )
    end
  end

  context "when pinning direct message channels" do
    fab!(:user_1, :user)
    fab!(:user_2, :user)
    fab!(:user_3, :user)
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [current_user, user_2]) }
    fab!(:dm_channel_3) { Fabricate(:direct_message_channel, users: [current_user, user_3]) }

    before do
      user_1.update!(username: "charlie")
      user_2.update!(username: "alice")
      user_3.update!(username: "bob")
    end

    it "shows the pinned DM channel at the top of the sidebar" do
      visit("/")

      chat_page.visit_channel_settings(dm_channel_1)

      membership = dm_channel_1.membership_for(current_user)

      expect {
        PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
        expect(toasts).to have_success(I18n.t("js.saved"))
      }.to change { membership.reload.pinned }.from(false).to(true)

      visit("/")

      expect(page.find("#sidebar-section-content-chat-dms li:nth-child(1)")).to have_css(
        ".channel-#{dm_channel_1.id}",
      )
    end

    it "shows a pin icon next to the pinned DM channel" do
      visit("/")

      chat_page.visit_channel_settings(dm_channel_1)

      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      visit("/")

      expect(page.find(".sidebar-section-link.channel-#{dm_channel_1.id}")).to have_css(
        ".sidebar-section-link-suffix.icon.pinned",
      )
    end

    it "sorts pinned DM channels alphabetically by title" do
      visit("/")

      # Pin dm_channel_1 (charlie)
      chat_page.visit_channel_settings(dm_channel_1)
      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      # Pin dm_channel_3 (bob)
      chat_page.visit_channel_settings(dm_channel_3)
      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      # Pin dm_channel_2 (alice)
      chat_page.visit_channel_settings(dm_channel_2)
      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      visit("/")

      # Should be ordered: alice, bob, charlie (alphabetically by title)
      expect(page.find("#sidebar-section-content-chat-dms li:nth-child(1)")).to have_css(
        ".channel-#{dm_channel_2.id}",
      )
      expect(page.find("#sidebar-section-content-chat-dms li:nth-child(2)")).to have_css(
        ".channel-#{dm_channel_3.id}",
      )
      expect(page.find("#sidebar-section-content-chat-dms li:nth-child(3)")).to have_css(
        ".channel-#{dm_channel_1.id}",
      )
    end

    it "shows pinned DM channels above unpinned DM channels" do
      visit("/")

      # Pin only dm_channel_1 (charlie)
      chat_page.visit_channel_settings(dm_channel_1)
      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__pin-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      visit("/")

      # dm_channel_1 (charlie - pinned) should be first, even though alice and bob come before it alphabetically
      expect(page.find("#sidebar-section-content-chat-dms li:nth-child(1)")).to have_css(
        ".channel-#{dm_channel_1.id}",
      )
    end
  end
end
