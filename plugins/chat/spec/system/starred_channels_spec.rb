# frozen_string_literal: true

RSpec.describe "Starred channels", type: :system do
  fab!(:current_user, :user)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:sidebar) { PageObjects::Pages::Sidebar.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    chat_system_bootstrap
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.star_chat_channels = true
    sign_in(current_user)
  end

  context "when starring a channel" do
    fab!(:channel_1) { Fabricate(:category_channel, name: "Channel A") }
    fab!(:channel_2) { Fabricate(:category_channel, name: "Channel B") }

    before do
      channel_1.add(current_user)
      channel_2.add(current_user)
    end

    it "shows the starred channel in the Starred Channels section" do
      visit("/")

      expect(page).to have_no_css("#sidebar-section-content-chat-starred-channels")

      chat_page.visit_channel_settings(channel_1)

      membership = channel_1.membership_for(current_user)

      expect {
        PageObjects::Components::DToggleSwitch.new(".c-channel-settings__star-switch").toggle
        expect(toasts).to have_success(I18n.t("js.saved"))
      }.to change { membership.reload.starred }.from(false).to(true)

      visit("/")

      expect(page).to have_css("#sidebar-section-content-chat-starred-channels")
      expect(
        page.find("#sidebar-section-content-chat-starred-channels li:nth-child(1)"),
      ).to have_css(".channel-#{channel_1.id}")
    end

    it "removes the starred channel from the regular Channels section" do
      visit("/")

      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(1)")).to have_css(
        ".channel-#{channel_1.id}",
      )

      chat_page.visit_channel_settings(channel_1)

      PageObjects::Components::DToggleSwitch.new(".c-channel-settings__star-switch").toggle
      expect(toasts).to have_success(I18n.t("js.saved"))

      visit("/")

      expect(page.find("#sidebar-section-content-chat-starred-channels")).to have_css(
        ".channel-#{channel_1.id}",
      )
      expect(page.find("#sidebar-section-content-chat-channels")).to have_no_css(
        ".channel-#{channel_1.id}",
      )
      expect(page.find("#sidebar-section-content-chat-channels")).to have_css(
        ".channel-#{channel_2.id}",
      )
    end
  end

  context "when starring multiple channels" do
    fab!(:channel_1) { Fabricate(:category_channel, name: "Channel C") }
    fab!(:channel_2) { Fabricate(:category_channel, name: "Channel A") }
    fab!(:channel_3) { Fabricate(:category_channel, name: "Channel B") }

    before do
      channel_1.add(current_user)
      channel_2.add(current_user)
      channel_3.add(current_user)
    end

    it "sorts starred channels alphabetically by slug in the Starred Channels section" do
      channel_1.membership_for(current_user).update!(starred: true)
      channel_2.membership_for(current_user).update!(starred: true)
      channel_3.membership_for(current_user).update!(starred: true)

      visit("/")

      expect(
        page.find("#sidebar-section-content-chat-starred-channels li:nth-child(1)"),
      ).to have_css(".channel-#{channel_2.id}")
      expect(
        page.find("#sidebar-section-content-chat-starred-channels li:nth-child(2)"),
      ).to have_css(".channel-#{channel_3.id}")
      expect(
        page.find("#sidebar-section-content-chat-starred-channels li:nth-child(3)"),
      ).to have_css(".channel-#{channel_1.id}")
    end

    it "shows unstarred channels in the regular Channels section" do
      channel_1.membership_for(current_user).update!(starred: true)

      visit("/")

      expect(page.find("#sidebar-section-content-chat-starred-channels")).to have_css(
        ".channel-#{channel_1.id}",
      )

      expect(page.find("#sidebar-section-content-chat-channels")).to have_no_css(
        ".channel-#{channel_1.id}",
      )
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(1)")).to have_css(
        ".channel-#{channel_2.id}",
      )
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(2)")).to have_css(
        ".channel-#{channel_3.id}",
      )
    end
  end

  context "when unstarring a channel" do
    fab!(:channel_1) { Fabricate(:category_channel, name: "Channel A") }
    fab!(:channel_2) { Fabricate(:category_channel, name: "Channel B") }

    before do
      channel_1.add(current_user)
      channel_2.add(current_user)

      channel_1.membership_for(current_user).update!(starred: true)
    end

    it "moves the channel from Starred Channels to regular Channels section" do
      visit("/")

      expect(page.find("#sidebar-section-content-chat-starred-channels")).to have_css(
        ".channel-#{channel_1.id}",
      )
      expect(page.find("#sidebar-section-content-chat-channels")).to have_no_css(
        ".channel-#{channel_1.id}",
      )

      chat_page.visit_channel_settings(channel_1)

      membership = channel_1.membership_for(current_user)

      expect {
        PageObjects::Components::DToggleSwitch.new(".c-channel-settings__star-switch").toggle
        expect(toasts).to have_success(I18n.t("js.saved"))
      }.to change { membership.reload.starred }.from(true).to(false)

      visit("/")

      expect(page).to have_no_css("#sidebar-section-content-chat-starred-channels")
      expect(page.find("#sidebar-section-content-chat-channels li:nth-child(1)")).to have_css(
        ".channel-#{channel_1.id}",
      )
    end
  end

  context "when all channels are starred" do
    fab!(:channel_1) { Fabricate(:category_channel, name: "Channel A") }
    fab!(:channel_2) { Fabricate(:category_channel, name: "Channel B") }

    before do
      channel_1.add(current_user)
      channel_2.add(current_user)

      channel_1.membership_for(current_user).update!(starred: true)
      channel_2.membership_for(current_user).update!(starred: true)
    end

    it "shows only the Starred Channels section" do
      visit("/")

      expect(page.find("#sidebar-section-content-chat-starred-channels")).to have_css(
        ".channel-#{channel_1.id}",
      )
      expect(page.find("#sidebar-section-content-chat-starred-channels")).to have_css(
        ".channel-#{channel_2.id}",
      )
    end
  end

  context "when starring direct message channels" do
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

    it "shows the starred DM channel in the Starred Channels section" do
      visit("/")

      chat_page.visit_channel_settings(dm_channel_1)

      membership = dm_channel_1.membership_for(current_user)

      expect {
        PageObjects::Components::DToggleSwitch.new(".c-channel-settings__star-switch").toggle
        expect(toasts).to have_success(I18n.t("js.saved"))
      }.to change { membership.reload.starred }.from(false).to(true)

      visit("/")

      expect(page.find("#sidebar-section-content-chat-starred-channels")).to have_css(
        ".channel-#{dm_channel_1.id}",
      )
    end

    it "removes the starred DM from the regular Direct Messages section" do
      dm_channel_1.membership_for(current_user).update!(starred: true)

      visit("/")

      expect(page.find("#sidebar-section-content-chat-starred-channels")).to have_css(
        ".channel-#{dm_channel_1.id}",
      )
      expect(page.find("#sidebar-section-content-chat-dms")).to have_no_css(
        ".channel-#{dm_channel_1.id}",
      )
    end

    it "sorts starred DM channels alphabetically by title in Starred Channels section" do
      dm_channel_1.membership_for(current_user).update!(starred: true)
      dm_channel_2.membership_for(current_user).update!(starred: true)
      dm_channel_3.membership_for(current_user).update!(starred: true)

      visit("/")

      starred_section = page.find("#sidebar-section-content-chat-starred-channels")
      expect(starred_section.find("li:nth-child(1)")).to have_css(".channel-#{dm_channel_2.id}")
      expect(starred_section.find("li:nth-child(2)")).to have_css(".channel-#{dm_channel_3.id}")
      expect(starred_section.find("li:nth-child(3)")).to have_css(".channel-#{dm_channel_1.id}")
    end
  end

  context "when starring both public channels and DMs" do
    fab!(:user_1, :user)
    fab!(:channel_1) { Fabricate(:category_channel, name: "Channel B") }
    fab!(:channel_2) { Fabricate(:category_channel, name: "Channel A") }
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

    before do
      user_1.update!(username: "alice")
      channel_1.add(current_user)
      channel_2.add(current_user)

      channel_1.membership_for(current_user).update!(starred: true)
      channel_2.membership_for(current_user).update!(starred: true)
      dm_channel_1.membership_for(current_user).update!(starred: true)
    end

    it "shows public channels first, then DMs in the Starred Channels section" do
      visit("/")

      starred_section = page.find("#sidebar-section-content-chat-starred-channels")
      expect(starred_section.find("li:nth-child(1)")).to have_css(".channel-#{channel_2.id}")
      expect(starred_section.find("li:nth-child(2)")).to have_css(".channel-#{channel_1.id}")
      expect(starred_section.find("li:nth-child(3)")).to have_css(".channel-#{dm_channel_1.id}")
    end
  end

  context "when the star_chat_channels setting is disabled" do
    fab!(:channel_1) { Fabricate(:category_channel, name: "Channel A") }

    before do
      channel_1.add(current_user)
      channel_1.membership_for(current_user).update!(starred: true)
      SiteSetting.star_chat_channels = false
    end

    it "does not show the Starred Channels section" do
      visit("/")

      expect(page).to have_no_css("#sidebar-section-content-chat-starred-channels")
      expect(page.find("#sidebar-section-content-chat-channels")).to have_css(
        ".channel-#{channel_1.id}",
      )
    end
  end
end
