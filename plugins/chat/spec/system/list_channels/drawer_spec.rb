# frozen_string_literal: true

RSpec.describe "List channels | Drawer", type: :system do
  fab!(:current_user, :user)

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
    chat.prefers_drawer
  end

  context "when channels tab" do
    context "when channels are available" do
      fab!(:category_channel_1, :category_channel)

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
      fab!(:channel_3) { Fabricate(:category_channel, name: "c channel", threading_enabled: true) }
      fab!(:channel_4) { Fabricate(:category_channel, name: "d channel") }
      fab!(:message) do
        Fabricate(:chat_message, chat_channel: channel_3, user: current_user, use_service: true)
      end
      fab!(:thread) do
        Fabricate(
          :chat_thread,
          channel: channel_3,
          original_message: message,
          with_replies: 2,
          use_service: true,
        )
      end

      before do
        channel_1.add(current_user)
        channel_2.add(current_user)
        channel_3.add(current_user)
        channel_4.add(current_user)
      end

      it "sorts them by urgent, unread messages or threads, then by slug" do
        drawer_page.visit_index

        Fabricate(
          :chat_message,
          chat_channel: channel_4,
          message: "@#{current_user.username}",
          use_service: true,
        )

        expect(drawer_page).to have_channel_at_position(channel_4, 1)
        expect(drawer_page).to have_channel_at_position(channel_3, 2)
        expect(drawer_page).to have_channel_at_position(channel_1, 3)
        expect(drawer_page).to have_channel_at_position(channel_2, 4)
      end

      it "sorts by slug when multiple channels have the same unread count" do
        drawer_page.visit_index
        Fabricate(:chat_message, chat_channel: channel_2, use_service: true)
        Fabricate(:chat_message, chat_channel: channel_4, use_service: true)

        expect(drawer_page).to have_channel_at_position(channel_2, 1)
        expect(drawer_page).to have_channel_at_position(channel_3, 2)
        expect(drawer_page).to have_channel_at_position(channel_4, 3)
        expect(drawer_page).to have_channel_at_position(channel_1, 4)
      end
    end
  end

  context "when no category channels" do
    it "shows the empty channel list" do
      drawer_page.visit_index
      expect(drawer_page).to have_selector(".empty-state")
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
      fab!(:dm_channel_1, :direct_message_channel)

      it "does not show the channel" do
        drawer_page.visit_index
        drawer_page.click_direct_messages

        expect(drawer_page).to have_no_channel(dm_channel_1)
      end
    end

    context "when multiple channels are present" do
      fab!(:user_1, :user)
      fab!(:user_2, :user)
      fab!(:user_3, :user)
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }
      fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }
      fab!(:dm_channel_3) do
        Fabricate(:direct_message_channel, users: [current_user, user_2], threading_enabled: true)
      end
      fab!(:dm_channel_4) do
        Fabricate(:direct_message_channel, users: [current_user, user_3], threading_enabled: true)
      end

      it "sorts them by latest activity" do
        Fabricate(
          :chat_message,
          chat_channel: dm_channel_2,
          user: user_1,
          use_service: true,
          created_at: 2.days.ago,
        )
        Fabricate(
          :chat_message,
          chat_channel: dm_channel_4,
          user: user_3,
          use_service: true,
          created_at: 1.day.ago,
        )
        dm_channel_4.membership_for(current_user).mark_read!

        drawer_page.visit_index
        drawer_page.click_direct_messages

        expect(drawer_page).to have_channel_at_position(dm_channel_2, 1)
        expect(drawer_page).to have_urgent_channel(dm_channel_2)
        expect(drawer_page).to have_channel_at_position(dm_channel_4, 2)
        expect(drawer_page).to have_channel_at_position(dm_channel_1, 3)
        expect(drawer_page).to have_channel_at_position(dm_channel_3, 4)
      end

      context "with unread threads" do
        fab!(:message_1) do
          Fabricate(
            :chat_message,
            chat_channel: dm_channel_3,
            user: current_user,
            use_service: true,
          )
        end
        fab!(:thread_1) do
          Fabricate(
            :chat_thread,
            channel: dm_channel_3,
            original_message: message_1,
            use_service: true,
          )
        end
        fab!(:message_2) do
          Fabricate(
            :chat_message,
            chat_channel: dm_channel_4,
            user: current_user,
            use_service: true,
          )
        end
        fab!(:thread_2) do
          Fabricate(
            :chat_thread,
            channel: dm_channel_4,
            original_message: message_2,
            use_service: true,
          )
        end

        before do
          dm_channel_3.membership_for(current_user).mark_read!(message_1.id)
          dm_channel_4.membership_for(current_user).mark_read!(message_2.id)

          drawer_page.visit_index
          drawer_page.click_direct_messages
        end

        it "sorts channels with unread threads by last reply" do
          Fabricate(:chat_message, thread: thread_1, user: user_2, use_service: true)
          Fabricate(:chat_message, thread: thread_2, user: user_3, use_service: true)

          expect(drawer_page).to have_channel_at_position(dm_channel_4, 1)
          expect(drawer_page).to have_unread_channel(dm_channel_4)

          expect(drawer_page).to have_channel_at_position(dm_channel_3, 2)
          expect(drawer_page).to have_unread_channel(dm_channel_3)
        end

        it "sorts channels with unread threads by importance" do
          thread_1.membership_for(current_user).update!(
            notification_level: ::Chat::NotificationLevels.all[:watching],
          )

          Fabricate(:chat_message, thread: thread_1, user: user_2, use_service: true)
          Fabricate(:chat_message, thread: thread_2, user: user_3, use_service: true)

          expect(drawer_page).to have_channel_at_position(dm_channel_3, 1)
          expect(drawer_page).to have_urgent_channel(dm_channel_3)

          expect(drawer_page).to have_channel_at_position(dm_channel_4, 2)
          expect(drawer_page).to have_unread_channel(dm_channel_4)
        end
      end
    end
  end

  context "when no direct message channels" do
    it "shows the empty channel list" do
      drawer_page.visit_index
      drawer_page.click_direct_messages

      expect(drawer_page).to have_selector(".empty-state")
    end
  end
end
