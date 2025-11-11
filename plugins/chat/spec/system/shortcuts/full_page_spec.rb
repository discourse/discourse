# frozen_string_literal: true

RSpec.describe "Shortcuts | full page", type: :system do
  fab!(:channel_1, :chat_channel)
  fab!(:current_user, :user)

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when pressing a letter" do
    it "intercepts the event and propagates it to the composer" do
      chat.visit_channel(channel_1)
      find(".header-sidebar-toggle").click # simple way to ensure composer is not focused

      page.send_keys("e")

      expect(channel_page.composer).to have_value("e")
    end
  end

  context "with chat search" do
    context "when disabled" do
      before { SiteSetting.chat_search_enabled = false }

      it "doesn't show the link to /chat/search" do
        visit("/")

        expect(page).to have_no_selector(".sidebar-section[data-section-name=\"chat-search\"]")
      end
    end

    context "when enabled" do
      before { SiteSetting.chat_search_enabled = true }

      it "shows the link the /chat/search" do
        visit("/")

        expect(page).to have_selector(".sidebar-section[data-section-name=\"chat-search\"]")
      end
    end
  end
end
