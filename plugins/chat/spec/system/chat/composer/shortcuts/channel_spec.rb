# frozen_string_literal: true

RSpec.describe "Chat | composer | shortcuts | channel" do
  fab!(:channel_1, :chat_channel)
  fab!(:current_user, :admin)

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:cdp) { PageObjects::CDP.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  it "adds bold, italic, and preformatted text through keyboard shortcuts" do
    chat.visit_channel(channel_1)
    composer = channel_page.composer

    composer.bold_text_shortcut
    expect(composer).to have_value("**strong text**")

    composer.fill_in(with: "")
    composer.emphasized_text_shortcut
    expect(composer).to have_value("_emphasized text_")

    composer.fill_in(with: "")
    composer.indented_text_shortcut
    expect(composer).to have_value("`indent preformatted text by 4 spaces`")
  end

  context "when the thread panel is also open" do
    fab!(:thread) do
      Fabricate(
        :chat_thread,
        channel: channel_1,
        original_message_user: current_user,
        with_replies: 1,
      )
    end

    before { channel_1.update!(threading_enabled: true) }

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

    it "replies to the last message with Shift+Up and edits the last editable message with Up" do
      chat.visit_channel(channel_1)

      channel_page.composer.reply_to_last_message_shortcut
      expect(channel_page.composer.message_details).to be_replying_to(message_2)

      channel_page.composer.cancel_editing
      expect(channel_page.composer).to be_editing_no_message

      channel_page.composer.edit_last_message_shortcut
      expect(channel_page.composer.message_details).to be_editing(message_1)
    end

    context "when last message is staged" do
      it "does not edit a message" do
        chat.visit_channel(channel_1)

        cdp.with_network_disconnected do
          channel_page.send_message
          channel_page.composer.edit_last_message_shortcut

          expect(channel_page.composer.message_details).to have_no_message
        end
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
  end
end
