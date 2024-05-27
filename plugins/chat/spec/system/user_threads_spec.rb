# frozen_string_literal: true

RSpec.describe "User threads", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:user_threads_page) { PageObjects::Pages::UserThreads.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when in sidebar" do
    context "when user is a member of at least one channel with threads" do
      before { channel_1.add(current_user) }

      it "shows a link to user threads" do
        visit("/")

        expect(sidebar_page).to have_user_threads_section
      end
    end

    context "when user is not a member of any channel with threads" do
      before do
        channel_1.update!(threading_enabled: false)
        channel_1.add(current_user)
      end

      it "does not show a link to user threads" do
        visit("/")

        expect(sidebar_page).to have_no_user_threads_section
      end
    end

    context "when user has unreads" do
      before do
        chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, Fabricate(:user)])
      end

      xit "has an unread indicator" do
        visit("/")

        expect(sidebar_page).to have_unread_user_threads
      end
    end

    it "has no unread indicator when user has no unreads" do
      visit("/")

      expect(sidebar_page).to have_no_unread_user_threads
    end

    it "lists threads" do
      Fabricate
        .times(5, :chat_channel, threading_enabled: true)
        .each do |channel|
          chat_thread_chain_bootstrap(
            channel: channel,
            users: [current_user, Fabricate(:user)],
            messages_count: 2,
          )
        end

      chat_page.visit_user_threads

      expect(user_threads_page).to have_threads(count: 5)
    end

    it "can load more threads" do
      Fabricate
        .times(20, :chat_channel, threading_enabled: true)
        .each do |channel|
          chat_thread_chain_bootstrap(
            channel: channel,
            users: [current_user, Fabricate(:user)],
            messages_count: 2,
          )
        end

      chat_page.visit_user_threads

      expect(user_threads_page).to have_threads(count: 10)

      page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

      expect(user_threads_page).to have_threads(count: 20)
    end

    it "can open a thread" do
      chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, Fabricate(:user)])

      chat_page.visit_user_threads
      user_threads_page.open_thread(channel_1.threads.first)

      expect(chat_page).to have_current_path(
        "/chat/c/#{channel_1.slug}/#{channel_1.id}/t/#{channel_1.threads.first.id} ",
      )
    end

    it "navigating back from a thread opens the user threads" do
      chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, Fabricate(:user)])

      chat_page.visit_user_threads
      user_threads_page.open_thread(channel_1.threads.first)
      thread_page.back

      expect(user_threads_page).to have_threads
    end

    it "updates the thread when another user replies" do
      chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, Fabricate(:user)])
      thread = channel_1.threads.last
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
    context "when user is a member of at least one channel with threads" do
      before { channel_1.add(current_user) }

      it "shows a link to user threads" do
        visit("/")
        chat_page.open_from_header

        expect(drawer_page).to have_user_threads_section
      end
    end

    context "when user is not a member of any channel with threads" do
      before do
        channel_1.update!(threading_enabled: false)
        channel_1.add(current_user)
      end

      it "does not show a link to user threads" do
        visit("/")
        chat_page.open_from_header

        expect(drawer_page).to have_no_user_threads_section
      end
    end

    context "when user has unreads" do
      before do
        chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, Fabricate(:user)])
      end

      xit "has an unread indicator" do
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
      Fabricate
        .times(5, :chat_channel, threading_enabled: true)
        .each do |channel|
          chat_thread_chain_bootstrap(
            channel: channel,
            users: [current_user, Fabricate(:user)],
            messages_count: 2,
          )
        end

      visit("/")
      chat_page.open_from_header
      drawer_page.click_user_threads

      expect(user_threads_page).to have_threads(count: 5)
    end

    it "can load more threads" do
      Fabricate
        .times(20, :chat_channel, threading_enabled: true)
        .each do |channel|
          chat_thread_chain_bootstrap(
            channel: channel,
            users: [current_user, Fabricate(:user)],
            messages_count: 2,
          )
        end

      visit("/")
      chat_page.open_from_header
      drawer_page.click_user_threads

      expect(user_threads_page).to have_threads(count: 10)

      page.execute_script(
        "document.querySelector('.chat-drawer-content').scrollTo(0, document.querySelector('.chat-drawer-content').scrollHeight)",
      )

      expect(user_threads_page).to have_threads(count: 20)
    end

    it "can open a thread" do
      chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, Fabricate(:user)])

      visit("/")
      chat_page.open_from_header
      drawer_page.click_user_threads
      user_threads_page.open_thread(channel_1.threads.first)

      expect(drawer_page).to have_open_thread(channel_1.threads.first)
    end

    it "navigating back from a thread opens the user threads" do
      chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, Fabricate(:user)])

      visit("/")
      chat_page.open_from_header
      drawer_page.click_user_threads
      user_threads_page.open_thread(channel_1.threads.first)
      drawer_page.back

      expect(user_threads_page).to have_threads
    end
  end

  context "when in mobile", mobile: true do
    before do
      last_message =
        chat_thread_chain_bootstrap(
          channel: channel_1,
          users: [current_user, Fabricate(:user)],
        ).last_message

      update_message!(last_message, text: "How's everyone doing?")
    end

    it "has the expected UI elements" do
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
end
