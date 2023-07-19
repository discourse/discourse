# frozen_string_literal: true

RSpec.describe "Chat | composer | shortcuts | channel", type: :system do
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:current_user) { Fabricate(:admin) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when using meta + b" do
    it "adds bold text" do
      chat.visit_channel(channel_1)

      channel_page.composer.bold_text_shortcut

      expect(channel_page.composer.value).to eq("**strong text**")
    end
  end

  context "when using meta + i" do
    it "adds italic text" do
      chat.visit_channel(channel_1)

      channel_page.composer.emphasized_text_shortcut

      expect(channel_page.composer.value).to eq("_emphasized text_")
    end
  end

  context "when using meta + e" do
    it "adds preformatted text" do
      chat.visit_channel(channel_1)

      channel_page.composer.indented_text_shortcut

      expect(channel_page.composer.value).to eq("`indent preformatted text by 4 spaces`")
    end
  end

  context "when the thread panel is also open" do
    fab!(:user_2) { Fabricate(:user) }
    fab!(:thread) do
      chat_thread_chain_bootstrap(
        channel: channel_1,
        users: [current_user, user_2],
        messages_count: 2,
      )
    end

    before do
      SiteSetting.enable_experimental_chat_threaded_discussions = true
      channel_1.update!(threading_enabled: true)
    end

    it "directs the shortcut to the focused composer" do
      chat.visit_channel(channel_1)
      channel_page.message_thread_indicator(thread.original_message).click
      channel_page.composer.emphasized_text_shortcut

      expect(channel_page.composer.value).to eq("_emphasized text_")
      expect(thread_page.composer.value).to eq("")

      channel_page.composer.fill_in(with: "")
      thread_page.composer.fill_in(with: "")

      thread_page.composer.emphasized_text_shortcut

      expect(channel_page.composer.value).to eq("")
      expect(thread_page.composer.value).to eq("_emphasized text_")
    end
  end

  context "when using ArrowUp" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1) }

    it "edits last editable message" do
      chat.visit_channel(channel_1)

      channel_page.composer.edit_last_message_shortcut

      expect(channel_page.composer.message_details).to be_editing(message_1)
    end

    context "when last message is staged" do
      it "does not edit a message" do
        chat.visit_channel(channel_1)
        page.driver.browser.network_conditions = { offline: true }
        channel_page.send_message
        channel_page.composer.edit_last_message_shortcut

        expect(channel_page.composer.message_details).to have_no_message
      ensure
        page.driver.browser.network_conditions = { offline: false }
      end
    end

    context "when last message is deleted" do
      before { message_1.trash! }

      it "does not edit a message" do
        chat.visit_channel(channel_1)

        channel_page.composer.edit_last_message_shortcut

        expect(channel_page.composer.message_details).to have_no_message
      end
    end

    context "with shift" do
      it "starts replying to the last message" do
        chat.visit_channel(channel_1)

        channel_page.composer.reply_to_last_message_shortcut

        expect(channel_page.composer.message_details).to be_replying_to(message_2)
      end
    end
  end
end
