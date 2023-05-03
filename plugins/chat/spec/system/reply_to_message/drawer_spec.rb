RSpec.describe "Reply to message - channel - drawer", type: :system, js: true do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }
  fab!(:original_message) do
    Fabricate(:chat_message, chat_channel: channel_1, user: Fabricate(:user))
  end

  before do
    SiteSetting.enable_experimental_chat_threaded_discussions = true
    chat_system_bootstrap
    channel_1.update!(threading_enabled: true)
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when the message has not current thread" do
    it "starts a thread" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel_1)
      channel_page.reply_to(original_message)
      expect(drawer_page).to have_open_thread

      thread_page.fill_composer("reply to message")
      thread_page.click_send_message

      expect(thread_page).to have_message(text: "reply to message")

      drawer_page.back

      expect(channel_page).to have_thread_indicator(original_message)
    end
  end

  context "when the message has an existing thread" do
    fab!(:message_1) do
      creator =
        Chat::MessageCreator.new(
          chat_channel: channel_1,
          in_reply_to_id: original_message.id,
          user: Fabricate(:user),
          content: Faker::Lorem.paragraph,
        )
      creator.create
      creator.chat_message
    end

    it "replies to the existing thread" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel_1)

      expect(channel_page).to have_thread_indicator(original_message, text: "1")

      channel_page.reply_to(original_message)

      expect(drawer_page).to have_open_thread

      thread_page.fill_composer("reply to message")
      thread_page.click_send_message

      expect(thread_page).to have_message(text: message_1.message)
      expect(thread_page).to have_message(text: "reply to message")

      drawer_page.back

      expect(channel_page).to have_thread_indicator(original_message, text: "2")
      expect(channel_page).to have_no_message(text: "reply to message")
    end
  end

  context "with threading disabled" do
    before { channel_1.update!(threading_enabled: false) }

    it "makes a reply in the channel" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel_1)
      channel_page.reply_to(original_message)

      expect(page).to have_selector(
        ".chat-channel .chat-reply__excerpt",
        text: original_message.message,
      )

      channel_page.fill_composer("reply to message")
      channel_page.click_send_message

      expect(channel_page).to have_message(text: "reply to message")
    end
  end
end
