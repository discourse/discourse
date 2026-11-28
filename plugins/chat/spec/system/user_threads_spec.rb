# frozen_string_literal: true

RSpec.describe "User threads" do
  fab!(:current_user, :user)
  fab!(:other_user, :user)
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:sidebar_page) { PageObjects::Pages::ChatSidebar.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:user_threads_page) { PageObjects::Pages::UserThreads.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when in sidebar" do
    context "when user has viewable threads" do
      it "shows a link to user threads" do
        create_tracked_thread(channel_1)
        visit("/")

        expect(sidebar_page).to have_user_threads_section
      end
    end

    context "when user has no viewable threads" do
      before { channel_1.add(current_user) }

      it "does not show a link to user threads" do
        visit("/")

        expect(sidebar_page).to have_no_user_threads_section
      end
    end

    context "when user has unreads" do
      it "has an unread indicator" do
        thread = create_tracked_thread(channel_1)
        thread.membership_for(current_user).mark_read!(thread.original_message_id)
        visit("/")

        expect(sidebar_page).to have_unread_user_threads
      end
    end

    it "has no unread indicator when user has no unreads" do
      visit("/")

      expect(sidebar_page).to have_no_unread_user_threads
    end

    it "lists threads" do
      create_tracked_threads(5)

      chat_page.visit_user_threads

      expect(user_threads_page).to have_threads(count: 5)
    end

    it "can load more threads" do
      # One thread beyond the first page is enough to exercise load-more.
      create_tracked_threads(11)

      chat_page.visit_user_threads

      expect(user_threads_page).to have_threads(count: 10)

      page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

      expect(user_threads_page).to have_threads(count: 11)
    end

    it "can open a thread and go back to the user threads list" do
      thread = create_tracked_thread(channel_1)

      chat_page.visit_user_threads
      user_threads_page.open_thread(thread)

      expect(chat_page).to have_current_path(thread.relative_url)

      thread_page.back

      expect(user_threads_page).to have_threads
    end

    it "updates the thread when another user replies" do
      thread = create_tracked_thread(channel_1, replies_count: 3)
      last_user = Fabricate(:user)

      chat_page.visit_user_threads

      last_message = Fabricate(:chat_message, thread: thread, user: last_user, use_service: true)

      indicator = PageObjects::Components::Chat::ThreadIndicator.new(".c-user-thread")
      expect(indicator).to have_reply_count(4)
      expect(indicator).to have_participant(last_user)
      expect(indicator).to have_excerpt(last_message.excerpt)
      expect(indicator).to have_user(last_user)
    end
  end

  context "when in drawer" do
    before { SiteSetting.chat_threads_enabled = true }

    context "when user has no viewable threads" do
      before { channel_1.add(current_user) }

      it "does not show a link to user threads" do
        visit("/")
        chat_page.open_from_header

        expect(drawer_page).to have_no_user_threads_section
      end
    end

    context "when user has unreads" do
      it "has an unread indicator" do
        thread = create_tracked_thread(channel_1)
        thread.membership_for(current_user).mark_read!(thread.original_message_id)
        visit("/")
        chat_page.open_from_header

        expect(drawer_page).to have_unread_user_threads
      end
    end

    it "has no unread indicator when user has no unreads" do
      visit("/")

      expect(sidebar_page).to have_no_unread_user_threads
    end

    it "lists threads" do
      create_tracked_threads(5)

      visit("/")
      chat_page.open_from_header
      drawer_page.click_user_threads

      expect(user_threads_page).to have_threads(count: 5)
    end

    it "can load more threads" do
      # One thread beyond the first page is enough to exercise load-more.
      create_tracked_threads(11)

      visit("/")
      chat_page.open_from_header
      drawer_page.click_user_threads

      expect(user_threads_page).to have_threads(count: 10)

      page.execute_script(
        "document.querySelector('.chat-drawer-content').scrollTo(0, document.querySelector('.chat-drawer-content').scrollHeight)",
      )

      expect(user_threads_page).to have_threads(count: 11)
    end

    it "can open a thread and go back to the user threads list" do
      thread = create_tracked_thread(channel_1)

      visit("/")
      chat_page.open_from_header
      expect(drawer_page).to have_user_threads_section

      drawer_page.click_user_threads
      user_threads_page.open_thread(thread)

      expect(drawer_page).to have_open_thread(thread)

      drawer_page.back

      expect(user_threads_page).to have_threads
    end
  end

  context "when in mobile", mobile: true do
    before { SiteSetting.chat_threads_enabled = true }

    it "has the expected UI elements" do
      create_tracked_thread(channel_1, reply_text: "How's everyone doing?")
      chat_page.visit_user_threads

      expect(user_threads_page).to have_threads(count: 1)
      expect(user_threads_page).to have_css(".chat-user-avatar")
      expect(user_threads_page).to have_css(".chat__thread-title__name")
      expect(user_threads_page).to have_css(".chat-channel-name")
      expect(user_threads_page).to have_css(".c-user-thread__excerpt")
      expect(user_threads_page).to have_css(".c-user-thread__excerpt-poster")
      expect(user_threads_page).to have_css(".c-user-thread .relative-date")

      expect(user_threads_page.excerpt_text).to eq("How's everyone doing?")
    end
  end

  private

  def create_tracked_threads(count)
    Fabricate
      .times(count, :chat_channel, threading_enabled: true)
      .each { |channel| create_tracked_thread(channel) }
  end

  def create_tracked_thread(channel, replies_count: 1, reply_text: nil)
    reply_users = [other_user, current_user].cycle.take(replies_count)
    thread =
      chat_thread_with_replies(
        channel: channel,
        original_message_user: current_user,
        reply_users: reply_users,
        link_replies: true,
        track_replies: true,
        reply_text: reply_text,
      )
    channel.add(current_user).mark_read!(thread.original_message_id)
    channel.add(other_user)
    channel.update_last_message_id!
    thread.membership_for(current_user).mark_read!
    thread
  end
end
