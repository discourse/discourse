# frozen_string_literal: true

RSpec.describe "Chat channel search - full page" do
  before do
    SearchIndexer.enable
    SiteSetting.chat_search_enabled = true
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  after { SearchIndexer.disable }

  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:author, :user)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  context "when searching for messages" do
    fab!(:message_1) do
      Fabricate(:chat_message, chat_channel: channel_1, user: author, message: "test 1")
    end
    fab!(:message_2) do
      Fabricate(:chat_message, chat_channel: channel_1, user: author, message: "test 2")
    end

    before do
      channel_1.update!(last_message: message_2)
      channel_1.add(author).update!(last_read_message: message_2)
      SearchIndexer.index(message_1)
      SearchIndexer.index(message_2)
    end

    it "allows navigating search results and deleting the query" do
      chat_page.visit_channel(channel_1)
      channel_page.filter.toggle.fill_in("test")

      expect(channel_page.messages).to have_message(id: message_2.id, highlighted: true)
      expect(page).to have_css(".chat-channel__filter-position", exact_text: "1 / 2")

      channel_page.filter.navigate_to_next_result

      expect(channel_page.messages).to have_message(id: message_1.id, highlighted: true)
      expect(page).to have_css(".chat-channel__filter-position", exact_text: "2 / 2")

      channel_page.filter.navigate_to_previous_result

      expect(channel_page.messages).to have_message(id: message_2.id, highlighted: true)
      expect(page).to have_css(".chat-channel__filter-position", exact_text: "1 / 2")

      find(".chat-channel__filter-bar input").send_keys(
        [SystemHelpers::PLATFORM_KEY_MODIFIER, "a"],
        :backspace,
      )
      expect(find(".chat-channel__filter-bar")).to have_field(with: "")
      expect(channel_page.filter).to have_no_state
    end

    it "clears the query and results with the Clear button" do
      chat_page.visit_channel(channel_1)
      channel_page.filter.toggle.fill_in("test")

      expect(page).to have_css(".chat-channel__filter-position", exact_text: "1 / 2")
      expect(page).to have_css(".chat-channel__prev-result")
      expect(page).to have_css(".chat-channel__next-result")
      expect(channel_page.messages).to have_message(id: message_2.id, highlighted: true)

      channel_page.filter.clear

      expect(channel_page.filter).to be_visible
      expect(find(".chat-channel__filter-bar")).to have_field(with: "")
      expect(page).to have_no_css(".chat-channel__filter-position", visible: :all)
      expect(page).to have_no_css(".chat-channel__prev-result", visible: :all)
      expect(page).to have_no_css(".chat-channel__next-result", visible: :all)
      expect(channel_page.messages).to have_message(id: message_2.id)
    end
  end

  it "opens a hidden filter and shows no results for an unmatched query" do
    chat_page.visit_channel(channel_1)
    expect(channel_page.filter).to be_not_visible

    channel_page.filter.toggle.fill_in("aaaaaaaaa")
    expect(channel_page.filter).to have_no_results
  end

  context "when search is not enabled" do
    before { SiteSetting.chat_search_enabled = false }

    it "does not show the filter button" do
      chat_page.visit_channel(channel_1)

      expect(channel_page.filter).to be_not_available
    end
  end
end
