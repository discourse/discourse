# frozen_string_literal: true

RSpec.describe "Drawer", type: :system, js: true do
  fab!(:current_user) { Fabricate(:admin) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when on channel" do
    fab!(:channel) { Fabricate(:chat_channel) }
    fab!(:membership) do
      Fabricate(:user_chat_channel_membership, user: current_user, chat_channel: channel)
    end

    context "when clicking channel title" do
      it "opens channel info page" do
        visit("/")
        chat_page.open_from_header
        drawer.open_channel(channel)
        page.find(".chat-channel-title").click

        expect(page).to have_current_path("/chat/c/#{channel.slug}/#{channel.id}/info/about")
      end
    end
  end

  context "when opening" do
    it "uses stored size" do
      visit("/") # we need to visit the page first to set the local storage

      page.execute_script "window.localStorage.setItem('discourse_chat_drawer_size_width','500');"
      page.execute_script "window.localStorage.setItem('discourse_chat_drawer_size_height','500');"

      visit("/")

      chat_page.open_from_header

      expect(page.find(".chat-drawer").native.style("width")).to eq("500px")
      expect(page.find(".chat-drawer").native.style("height")).to eq("500px")
    end

    it "has a default size" do
      visit("/")

      chat_page.open_from_header

      expect(page.find(".chat-drawer").native.style("width")).to eq("400px")
      expect(page.find(".chat-drawer").native.style("height")).to eq("530px")
    end
  end

  context "when toggling open/close" do
    it "toggles a css class on body" do
      visit("/")

      chat_page.open_from_header

      expect(page.find("body.chat-drawer-active")).to be_visible

      drawer.close

      expect(page.find("body:not(.chat-drawer-active)")).to be_visible
    end
  end

  context "when going from drawer to full page" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:channel_2) { Fabricate(:chat_channel) }
    fab!(:user_1) { Fabricate(:user) }

    before do
      channel_1.add(current_user)
      channel_2.add(current_user)
      channel_1.add(user_1)
      channel_2.add(user_1)
    end

    it "correctly resets subscriptions" do
      visit("/")

      chat_page.open_from_header
      drawer.maximize
      chat_page.minimize_full_page
      drawer.maximize

      using_session("user_1") do |session|
        sign_in(user_1)
        chat_page.visit_channel(channel_1)
        channel_page.send_message("onlyonce")
        session.quit
      end

      expect(page).to have_content("onlyonce", count: 1)

      chat_page.visit_channel(channel_2)

      expect(page).to have_content("onlyonce", count: 0)
    end
  end
end
