# frozen_string_literal: true

RSpec.describe "Bot", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:current_user) { Discourse.system_user }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when not allowed to chat" do
    before { SiteSetting.chat_allowed_groups = "" }

    it "can send a message in a public channel" do
      channel_1 = Fabricate(:category_channel)
      message_1 =
        Fabricate(:chat_message, chat_channel: channel_1, user: current_user, use_service: true)
      chat_page.visit_channel(channel_1)

      expect(channel_page.messages).to have_message(id: message_1.id)
    end
  end

  context "when not allowed to use direct message" do
    before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:staff] }

    it "can send a message in a direct message channel" do
      channel_1 = Fabricate(:direct_message_channel)
      message_1 =
        Fabricate(:chat_message, chat_channel: channel_1, user: current_user, use_service: true)
      chat_page.visit_channel(channel_1)

      expect(channel_page.messages).to have_message(id: message_1.id)
    end
  end
end
