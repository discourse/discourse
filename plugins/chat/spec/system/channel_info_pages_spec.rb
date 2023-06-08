# frozen_string_literal: true

RSpec.describe "Info pages", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when visiting from browse page" do
    context "when clicking back button" do
      it "redirects to browse page" do
        chat_page.visit_browse
        find(".chat-channel-card__setting").click
        find(".chat-full-page-header__back-btn").click

        expect(page).to have_current_path("/chat/browse/open")
      end
    end
  end

  context "when visiting from channel page" do
    context "when clicking back button" do
      it "redirects to channel page" do
        chat_page.visit_channel(channel_1)
        find(".chat-channel-title-wrapper").click
        find(".chat-full-page-header__back-btn").click

        expect(page).to have_current_path(chat.channel_path(channel_1.slug, channel_1.id))
      end
    end
  end
end
