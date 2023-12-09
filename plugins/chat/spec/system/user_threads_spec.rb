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
    it "shows a link to user threads" do
      visit("/")

      expect(sidebar_page).to have_user_threads_section
    end

    context "when user has unreads" do
      before do
        chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, Fabricate(:user)])
      end

      it "has an unread indicator" do
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
  end

  context "when in drawer" do
    it "shows a link to user threads" do
      visit("/")
      chat_page.open_from_header

      expect(drawer_page).to have_user_threads_section
    end

    context "when user has unreads" do
      before do
        chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, Fabricate(:user)])
      end

      it "has an unread indicator" do
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
end
