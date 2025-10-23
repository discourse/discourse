# frozen_string_literal: true

RSpec.describe "Chat channel search - drawer", type: :system do
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

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  context "when searching for messages" do
    it "shows search results and allows navigation" do
      message_1 =
        Fabricate(:chat_message, chat_channel: channel_1, message: "test 1", use_service: true)
      message_2 =
        Fabricate(:chat_message, chat_channel: channel_1, message: "test 2", use_service: true)

      drawer_page.visit_channel(channel_1)
      channel_page.filter.toggle.fill_in("test")

      expect(channel_page.messages).to have_message(id: message_2.id, highlighted: true)
      expect(channel_page.filter).to have_state(results: 2, position: 1)

      channel_page.filter.navigate_to_next_result

      expect(channel_page.messages).to have_message(id: message_1.id, highlighted: true)
      expect(channel_page.filter).to have_state(results: 2, position: 2)

      channel_page.filter.navigate_to_previous_result

      expect(channel_page.messages).to have_message(id: message_2.id, highlighted: true)
      expect(channel_page.filter).to have_state(results: 2, position: 1)
    end

    it "shows no results message when no matches found" do
      drawer_page.visit_channel(channel_1)

      channel_page.filter.toggle.fill_in("aaaaaaaaa")

      expect(channel_page.filter).to have_no_results
    end
  end

  context "when filter is not toggled" do
    it "does not show search functionality" do
      drawer_page.visit_channel(channel_1)

      expect(channel_page.filter).to be_not_visible
    end
  end

  context "when search is not enabled" do
    before { SiteSetting.chat_search_enabled = false }

    it "does not show the filter button" do
      drawer_page.visit_channel(channel_1)

      expect(channel_page.filter).to be_not_available
    end
  end
end
