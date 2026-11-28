# frozen_string_literal: true

describe "Thread list in side panel | drawer" do
  fab!(:current_user, :admin)
  fab!(:channel, :chat_channel)
  fab!(:other_user, :user)

  let(:chat_page) { PageObjects::Pages::Chat.new }
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
      expect(find(".chat-drawer")).not_to have_css(drawer_page.thread_list_button_selector)
    end
  end

  context "when threading is enabled for the channel" do
    before { channel.update!(threading_enabled: true) }

    fab!(:threads) do
      ["favourite album?", "current event"].map do |title|
          thread =
            chat_thread_with_replies(
              channel: channel,
              original_message_user: other_user,
              reply_users: [current_user],
              title: title,
            )
          channel.add(other_user).mark_read!(thread.original_message_id)
          thread.add(current_user).mark_read!(thread.last_message_id)
          thread
        end
        .tap { channel.update_last_message_id! }
    end

    it "opens the thread list from the header, shows thread titles, and lets the user open a thread" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list

      expect(drawer_page).to have_open_thread_list
      threads.each { |thread| expect(thread_list_page).to have_content(thread.title) }

      thread = threads.first
      thread_list_page.item_by_id(thread.id).click

      expect(drawer_page).to have_open_thread(thread)
    end
  end
end
