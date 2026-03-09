# frozen_string_literal: true

RSpec.describe "Chat message codeblock", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  fab!(:current_user, :user)
  fab!(:channel_1, :category_channel)

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when sending a message with a codeblock" do
    it "renders the codeblock and shows the copy button" do
      SiteSetting.chat_show_copy_button_on_codeblocks = true
      chat_page.visit_channel(channel_1)
      channel_page.send_message(
        "Here is some code:\n```ruby\ndef hello\n  puts 'Hello, world!'\nend\n```",
      )

      expect(page).to have_selector(".chat-message .codeblock-buttons")
      expect(page).to have_selector(".chat-message .codeblock-buttons .codeblock-button-wrapper")
    end
  end

  context "when the setting to show copy button on codeblocks is disabled" do
    it "renders the codeblock but does not show the copy button" do
      SiteSetting.chat_show_copy_button_on_codeblocks = false
      chat_page.visit_channel(channel_1)
      channel_page.send_message(
        "Here is some code:\n```ruby\ndef hello\n  puts 'Hello, world!'\nend\n```",
      )

      expect(page).to have_selector(".chat-message pre code")
      expect(page).not_to have_selector(
        ".chat-message .codeblock-buttons .codeblock-button-wrapper",
      )
    end
  end
end
