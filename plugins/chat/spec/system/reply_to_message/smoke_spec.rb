# frozen_string_literal: true

RSpec.describe "Reply to message - smoke", type: :system, js: true do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }

  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }
  fab!(:original_message) do
    Fabricate(:chat_message, chat_channel: channel_1, user: Fabricate(:user))
  end

  before do
    SiteSetting.enable_experimental_chat_threaded_discussions = true
    chat_system_bootstrap
    channel_1.add(user_1)
    channel_1.add(user_2)
    channel_1.update!(threading_enabled: true)
  end

  context "when two users create a thread on the same message" do
    it "works" do
      using_session(:user_1) do
        sign_in(user_1)
        chat_page.visit_channel(channel_1)
        channel_page.reply_to(original_message)
      end

      using_session(:user_2) do
        sign_in(user_2)
        chat_page.visit_channel(channel_1)
        channel_page.reply_to(original_message)
      end

      using_session(:user_1) do
        thread_page.fill_composer("user1reply")
        thread_page.click_send_message

        expect(channel_page).to have_thread_indicator(original_message, text: "1")

        expect(thread_page).to have_message(text: "user1reply")
      end

      using_session(:user_2) do |session|
        expect(thread_page).to have_message(text: "user1reply")
        expect(channel_page).to have_thread_indicator(original_message, text: "1")

        thread_page.fill_composer("user2reply")
        thread_page.click_send_message

        expect(thread_page).to have_message(text: "user2reply")
        expect(channel_page).to have_thread_indicator(original_message, text: "2")

        refresh

        expect(thread_page).to have_message(text: "user1reply")
        expect(thread_page).to have_message(text: "user2reply")
        expect(channel_page).to have_thread_indicator(original_message, text: "2")

        session.quit
      end

      using_session(:user_1) do |session|
        expect(thread_page).to have_message(text: "user2reply")
        expect(channel_page).to have_thread_indicator(original_message, text: "2")

        refresh

        expect(thread_page).to have_message(text: "user1reply")
        expect(thread_page).to have_message(text: "user2reply")
        expect(channel_page).to have_thread_indicator(original_message, text: "2")

        session.quit
      end
    end
  end
end
