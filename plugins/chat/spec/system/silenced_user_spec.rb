# frozen_string_literal: true

RSpec.describe "Silenced user", type: :system, js: true do
  fab!(:channel_1) { Fabricate(:category_channel) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  context "when user is silenced" do
    fab!(:silenced_user) { Fabricate(:user) }

    before do
      UserSilencer.silence(silenced_user)
      channel_1.add(silenced_user)
      sign_in(silenced_user)
      chat.visit_channel(channel_1)
    end

    it "disables the composer" do
      chat.visit_channel(channel_1)

      expect(page).to have_field(
        placeholder: I18n.t("js.chat.placeholder_silenced"),
        disabled: true,
      )
    end

    it "disables the send button" do
      chat.visit_channel(channel_1)

      expect(page).to have_css(".chat-composer__send-btn[disabled]")
    end

    it "prevents reactions" do
      message_1 = Fabricate(:chat_message, chat_channel: channel_1)
      chat.visit_channel(channel_1)
      channel.hover_message(message_1)

      expect(page).to have_no_css(".chat-message-actions")
    end
  end
end
