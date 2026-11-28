# frozen_string_literal: true

RSpec.describe "Chat search" do
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

  fab!(:message_1_channel_1) do
    Fabricate(:chat_message, chat_channel: channel_1, message: "message 1 music lounge")
  end
  fab!(:message_1_channel_2) do
    Fabricate(:chat_message, chat_channel: channel_2, message: "message 1 sports arena")
  end

  let(:chat_search_page) { PageObjects::Pages::ChatSearch.new }

  context "when searching for messages" do
    it "shows matching results across channels and narrows them" do
      SearchIndexer.index(message_1_channel_1)
      SearchIndexer.index(message_1_channel_2)

      chat_search_page.visit

      chat_search_page.fill_in("message 1")

      [message_1_channel_1, message_1_channel_2].each do |message|
        expect(page).to have_css(
          ".c-routes.--search .chat-message-container[data-id='#{message.id}']",
        )
      end

      chat_search_page.fill_in("music lounge")

      expect(chat_search_page).to have_x_results(1)
      expect(page).to have_css(
        ".c-routes.--search .chat-message-container[data-id='#{message_1_channel_1.id}']",
      )
    end

    it "shows a no-results message for a non-matching first query" do
      chat_search_page.visit.fill_in("aaaaaaaa")

      expect(page).to have_css(".c-routes.--search .alert.alert-info")
    end

    it "can click on a result" do
      message =
        Fabricate(:chat_message, chat_channel: channel_1, message: "test", use_service: true)

      chat_search_page.visit.fill_in("test").click_result(message)

      expect(page).to have_current_path(
        "/chat/c/#{message.chat_channel.slug}/#{message.chat_channel.id}",
      )
    end

    context "when results span more than one page" do
      fab!(:searchable_messages) do
        (1..21).map do |number|
          Fabricate(
            :chat_message,
            chat_channel: channel_1,
            user: current_user,
            message: "test #{number}",
          )
        end
      end

      it "can load more results" do
        searchable_messages.each { |message| SearchIndexer.index(message) }

        chat_search_page.visit.fill_in("test")

        expect(chat_search_page).to have_x_results(20)

        chat_search_page.scroll_to_bottom

        expect(chat_search_page).to have_x_results(21)
      end
    end

    it "can clear the search input" do
      Fabricate(:chat_message, chat_channel: channel_1, message: "test message", use_service: true)

      chat_search_page.visit.fill_in("test")

      expect(chat_search_page).to have_x_results(1)

      chat_search_page.clear

      within(".c-routes.--search") do
        expect(page).to have_field(class: "filter-input", with: "")
        expect(page).to have_no_css(".chat-message-search-entry")
      end
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
