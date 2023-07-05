# frozen_string_literal: true

RSpec.describe "User status | chat message", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:another_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }

  let(:chat) { PageObjects::Pages::Chat.new }

  before do
    SiteSetting.enable_user_status = true
    chat_system_bootstrap

    channel_1.add(current_user)
    channel_1.add(another_user)
    current_user.set_status!("off to dentist", "tooth")
    another_user.set_status!("surfing", "surfing_man")

    sign_in(current_user)
  end

  context "when user pasted a message with mentions to the composer" do
    it "renders user status on mentions" do
      chat.visit_channel(channel_1)

      message = "Hey @#{current_user.username} @#{another_user.username}, how are you?"
      find(".chat-composer__input").fill_in(with: message)
      find(".chat-composer.is-send-enabled .chat-composer-button.-send").click

      expect(page).to have_selector(
        ".mention .user-status-message .emoji[alt='#{current_user.user_status.emoji}']",
      )
      expect(page).to have_selector(
        ".mention .user-status-message .emoji[alt='#{another_user.user_status.emoji}']",
      )
    end
  end
end
