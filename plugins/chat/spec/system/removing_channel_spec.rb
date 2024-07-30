# frozen_string_literal: true

RSpec.describe "Removing channel", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_sidebar_page) { PageObjects::Pages::Sidebar.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when removing last followed channel" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:channel_2) { Fabricate(:direct_message_channel, users: [current_user, Fabricate(:user)]) }

    before do
      Fabricate(
        :user_chat_channel_membership,
        user: current_user,
        chat_channel: channel_1,
        following: false,
      )
    end

    it "redirects to browse page" do
      chat_page.visit_channel(channel_2)
      chat_sidebar_page.remove_channel(channel_2)

      expect(page).to have_current_path("/chat/browse/open")
    end
  end

  context "when removing channel" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:channel_2) { Fabricate(:direct_message_channel, users: [current_user, Fabricate(:user)]) }

    before do
      current_user.upsert_custom_fields(::Chat::LAST_CHAT_CHANNEL_ID => channel_1.id)
      channel_1.add(current_user)
    end

    it "redirects to another followed channgel" do
      chat_page.visit_channel(channel_2)
      chat_sidebar_page.remove_channel(channel_2)

      expect(page).to have_current_path(chat.channel_path(channel_1.slug, channel_1.id))
    end
  end
end
