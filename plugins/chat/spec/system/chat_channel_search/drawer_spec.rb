# frozen_string_literal: true

RSpec.describe "Chat channel search - drawer" do
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

  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

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

    it "clears the first search with the Clear button and navigates a new search" do
      drawer_page.visit_channel(channel_1)
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

      channel_page.filter.fill_in("test")

      expect(channel_page.messages).to have_message(id: message_2.id, highlighted: true)
      expect(page).to have_css(".chat-channel__filter-position", exact_text: "1 / 2")

      channel_page.filter.navigate_to_next_result

      expect(channel_page.messages).to have_message(id: message_1.id, highlighted: true)
      expect(page).to have_css(".chat-channel__filter-position", exact_text: "2 / 2")

      channel_page.filter.navigate_to_previous_result

      expect(channel_page.messages).to have_message(id: message_2.id, highlighted: true)
      expect(page).to have_css(".chat-channel__filter-position", exact_text: "1 / 2")
    end
  end

  it "opens a hidden filter, shows no results, and closes it on Escape" do
    drawer_page.visit_channel(channel_1)
    expect(channel_page.filter).to be_not_visible

    channel_page.filter.toggle
    expect(channel_page.filter).to be_visible

    channel_page.filter.fill_in("aaaaaaaaa")
    expect(channel_page.filter).to have_no_results

    page.send_keys(:escape)
    expect(channel_page.filter).to be_not_visible
  end

  context "when search is not enabled" do
    before { SiteSetting.chat_search_enabled = false }

    it "does not show the filter button" do
      drawer_page.visit_channel(channel_1)

      expect(channel_page.filter).to be_not_available
    end
  end
end
