# frozen_string_literal: true

RSpec.describe "List channels | Drawer", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
    chat.prefers_drawer
  end

  context "when channels tab" do
    context "when channels are available" do
      fab!(:category_channel_1) { Fabricate(:category_channel) }

      context "when member of the channel" do
        before { category_channel_1.add(current_user) }

        it "shows the channel" do
          drawer_page.visit_index
          expect(drawer_page).to have_channel(category_channel_1)
        end
      end

      context "when not member of the channel" do
        it "does not show the channel" do
          drawer_page.visit_index
          expect(drawer_page).to have_no_channel(category_channel_1)
        end
      end
    end

    context "when multiple channels are present" do
      fab!(:channel_1) { Fabricate(:category_channel, name: "a channel") }
      fab!(:channel_2) { Fabricate(:category_channel, name: "b channel") }
      fab!(:channel_3) { Fabricate(:category_channel, name: "c channel") }
      fab!(:channel_4) { Fabricate(:category_channel, name: "d channel") }

      before do
        channel_1.add(current_user)
        channel_2.add(current_user)
        channel_3.add(current_user)
        channel_4.add(current_user)
      end

      it "sorts them by urgent, unread, then by slug" do
        drawer_page.visit_index

        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          created_at: 5.minutes.ago,
          use_service: true,
        )
        Fabricate(
          :chat_message,
          chat_channel: channel_2,
          created_at: 2.minutes.ago,
          use_service: true,
        )
        Fabricate(
          :chat_message,
          chat_channel: channel_3,
          message: "@#{current_user.username}",
          use_service: true,
        )
        Fabricate(:chat_message, chat_channel: channel_4, use_service: true)

        expect(drawer_page).to have_channel_at_position(channel_3, 1)
        expect(drawer_page).to have_channel_at_position(channel_1, 2)
        expect(drawer_page).to have_channel_at_position(channel_2, 3)
      end
    end
  end

  context "when no category channels" do
    it "shows the empty channel list" do
      drawer_page.visit_index
      expect(drawer_page).to have_selector(".channel-list-empty-message")
    end
  end

  context "when direct messages tab" do
    context "when member of the channel" do
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

      it "shows the channel" do
        drawer_page.visit_index
        drawer_page.click_direct_messages

        expect(drawer_page).to have_channel(dm_channel_1)
      end
    end

    context "when not member of the channel" do
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel) }

      it "does not show the channel" do
        drawer_page.visit_index
        drawer_page.click_direct_messages

        expect(drawer_page).to have_no_channel(dm_channel_1)
      end
    end

    context "when multiple channels are present" do
      fab!(:user_1) { Fabricate(:user) }
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }
      fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

      before do
        Fabricate(:chat_message, chat_channel: dm_channel_2, user: user_1, use_service: true)
      end

      it "sorts them by latest activity" do
        drawer_page.visit_index
        drawer_page.click_direct_messages

        expect(drawer_page).to have_channel_at_position(dm_channel_2, 1)
        expect(drawer_page).to have_channel_at_position(dm_channel_1, 2)
      end
    end
  end

  context "when no direct message channels" do
    it "shows the empty channel list" do
      drawer_page.visit_index
      drawer_page.click_direct_messages

      expect(drawer_page).to have_selector(".channel-list-empty-message")
    end
  end
end
