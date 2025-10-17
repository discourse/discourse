# frozen_string_literal: true

RSpec.describe "Chat search", type: :system do
  before do
    SearchIndexer.enable
    SiteSetting.chat_search_enabled = true
    chat_system_bootstrap
    channel_1.add(current_user)
    channel_2.add(current_user)
    sign_in(current_user)
  end

  after { SearchIndexer.disable }

  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:channel_2, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_search_page) { PageObjects::Pages::ChatSearch.new }

  context "when searching for messages" do
    it "shows search results for multiple channels" do
      message_1_channel_1 =
        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          message: "message 1 channel 1",
          use_service: true,
        )
      message_1_channel_2 =
        Fabricate(
          :chat_message,
          chat_channel: channel_2,
          message: "message 1 channel 2",
          use_service: true,
        )

      chat_search_page.visit

      chat_search_page.fill_in("message 1")

      expect(chat_search_page).to have_results(message_1_channel_1, message_1_channel_2)

      chat_search_page.fill_in("channel 1")

      expect(chat_search_page).to have_results(message_1_channel_1)
    end

    it "can click on a result" do
      message =
        Fabricate(:chat_message, chat_channel: channel_1, message: "test", use_service: true)

      chat_search_page.visit.fill_in("test").click_result(message)

      expect(page).to have_current_path(
        "/chat/c/#{message.chat_channel.slug}/#{message.chat_channel.id}",
      )
    end

    it "shows no results message when no matches found" do
      chat_search_page.visit.fill_in("aaaaaaaa")

      expect(chat_search_page).to have_no_results
    end

    it "can load more results" do
      Fabricate.times(
        21,
        :chat_message,
        chat_channel: channel_1,
        message: "test",
        use_service: true,
      )

      chat_search_page.visit.fill_in("test")

      expect(chat_search_page).to have_x_results(20)

      chat_search_page.scroll_to_bottom

      expect(chat_search_page).to have_x_results(21)
    end
  end

  context "with search disabled" do
    before { SiteSetting.chat_search_enabled = false }

    it "can't access search" do
      chat_search_page.visit

      expect(page).to have_current_path("/chat/browse/open")
    end
  end
end
