# frozen_string_literal: true

RSpec.describe "Invite users to channel", type: :system do
  fab!(:user_1) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  let(:user_menu) { PageObjects::Components::UserMenu.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    channel_1.add(user_1)
    sign_in(user_1)
  end

  context "when user clicks the invitation" do
    context "when the invitation is linking to a channel" do
      before do
        Chat::InviteUsersToChannel.call(
          guardian: Guardian.new(Fabricate(:admin)),
          params: {
            channel_id: channel_1.id,
            user_ids: [user_1.id],
          },
        )
      end

      it "loads the channel" do
        visit("/")
        user_menu.open
        find("[title='#{I18n.t("js.notifications.titles.chat_invitation")}']").click

        expect(chat_drawer_page).to have_open_channel(channel_1)
      end
    end

    context "when the invitation is linking to a message" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

      before do
        Chat::InviteUsersToChannel.call(
          guardian: Guardian.new(Fabricate(:admin)),
          params: {
            channel_id: channel_1.id,
            user_ids: [user_1.id],
            message_id: message_1.id,
          },
        )
      end

      it "loads the channel" do
        visit("/")
        user_menu.open
        find("[title='#{I18n.t("js.notifications.titles.chat_invitation")}']").click

        expect(chat_drawer_page).to have_open_channel(channel_1)
      end
    end
  end
end
