# frozen_string_literal: true

describe "Thread list in side panel | drawer", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:channel) { Fabricate(:chat_channel) }
  fab!(:other_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:thread_list_page) { PageObjects::Components::Chat::ThreadList.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap(current_user, [channel])
    sign_in(current_user)
  end

  context "when threading not enabled for the channel" do
    before { channel.update!(threading_enabled: false) }

    it "does not show the thread list button in drawer header" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      expect(find(".chat-drawer-header__right-actions")).not_to have_css(
        drawer_page.thread_list_button_selector,
      )
    end
  end

  context "when threading is enabled for the channel" do
    before { channel.update!(threading_enabled: true) }

    fab!(:thread_1) do
      chat_thread_chain_bootstrap(
        channel: channel,
        users: [current_user, other_user],
        thread_attrs: {
          title: "favourite album?",
        },
      )
    end
    fab!(:thread_2) do
      chat_thread_chain_bootstrap(
        channel: channel,
        users: [current_user, other_user],
        thread_attrs: {
          title: "current event",
        },
      )
    end

    it "opens the thread list from the header button" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list
      expect(drawer_page).to have_open_thread_list
    end

    it "shows the titles of the threads the user is participating in" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list
      expect(drawer_page).to have_open_thread_list
      expect(thread_list_page).to have_content(thread_1.title)
      expect(thread_list_page).to have_content(thread_2.title)
    end

    it "opens a thread" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list
      expect(drawer_page).to have_open_thread_list
      thread_list_page.item_by_id(thread_1.id).click
      expect(drawer_page).to have_open_thread(thread_1)
    end
  end
end
