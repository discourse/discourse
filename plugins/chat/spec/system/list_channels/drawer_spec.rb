# frozen_string_literal: true

RSpec.describe "List channels | Drawer" do
  fab!(:current_user, :user)
  fab!(:admin)

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap(admin)
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
      fab!(:sender, :user)
      fab!(:thread) do
        Fabricate(:chat_thread, channel: channel_3, original_message_user: current_user)
      end
      fab!(:reply) do
        Fabricate(:chat_message, chat_channel: channel_3, thread: thread, user: sender)
      end

      before do
        channel_1.add(current_user)
        channel_2.add(current_user)
        channel_3.update!(last_message_id: thread.original_message_id, messages_count: 1)
        channel_3.add(current_user).mark_read!(thread.original_message_id)
        channel_3.add(sender)
        thread.update_last_message_id!
        thread.set_replies_count_cache(1, update_db: true)
        thread.membership_for(current_user).mark_read!(thread.original_message_id)
        thread.add(sender).mark_read!(reply.id)
        channel_4.add(current_user)
      end

      it "sorts by urgent, unread messages or threads first when priority is selected" do
        current_user.user_option.update!(chat_channel_list_sort: "priority")
        [channel_1, channel_2].each_with_index do |channel, index|
          message =
            Fabricate(
              :chat_message,
              chat_channel: channel,
              user: current_user,
              created_at: (2 - index).days.ago,
            )
          channel.update!(last_message: message, messages_count: 1)
          channel.membership_for(current_user).mark_read!(message.id)
        end
        drawer_page.visit_index

        Fabricate(
          :chat_message,
          chat_channel: channel_4,
          message: "@#{current_user.username}",
          user: sender,
          use_service: true,
        )

        expect(drawer_page).to have_urgent_channel(channel_4)
        expect(drawer_page).to have_unread_channel(channel_3)
        expect(drawer_page).to have_channel_at_position(channel_4, 1)
        expect(drawer_page).to have_channel_at_position(channel_3, 2)
        expect(drawer_page).to have_channel_at_position(channel_1, 3)
        expect(drawer_page).to have_channel_at_position(channel_2, 4)
      end

      it "offers sort options and keeps the default alphabetical order with unreads" do
        drawer_page.visit_index
        expect(drawer_page.channels_index.component).to have_css(
          ".chat-channel-list-options-button",
        )

        Fabricate(:chat_message, chat_channel: channel_2, user: sender, use_service: true)
        Fabricate(:chat_message, chat_channel: channel_4, user: sender, use_service: true)

        expect(drawer_page).to have_unread_channel(channel_2)
        expect(drawer_page).to have_unread_channel(channel_4)
        expect(drawer_page).to have_channel_at_position(channel_1, 1)
        expect(drawer_page).to have_channel_at_position(channel_2, 2)
        expect(drawer_page).to have_channel_at_position(channel_3, 3)
        expect(drawer_page).to have_channel_at_position(channel_4, 4)
      end

      it "sorts by recent activity from the sort menu and persists the choice" do
        older_message =
          Fabricate(
            :chat_message,
            chat_channel: channel_1,
            user: current_user,
            created_at: 3.days.ago,
          )
        recent_message =
          Fabricate(
            :chat_message,
            chat_channel: channel_2,
            user: current_user,
            created_at: 1.hour.ago,
          )
        channel_1.update!(last_message: older_message, messages_count: 1)
        channel_2.update!(last_message: recent_message, messages_count: 1)
        channel_1.membership_for(current_user).mark_read!(older_message.id)
        channel_2.membership_for(current_user).mark_read!(recent_message.id)

        drawer_page.visit_index

        ids = page.all(".chat-channel-row").map { |c| c["data-chat-channel-id"] }
        expect(ids.index(channel_1.id.to_s)).to be < ids.index(channel_2.id.to_s)

        drawer_page.channels_index.set_channel_sort("recent_activity")

        try_until_success do
          ids = page.all(".chat-channel-row").map { |c| c["data-chat-channel-id"] }
          expect(ids.index(channel_2.id.to_s)).to be < ids.index(channel_1.id.to_s)
        end
        try_until_success do
          expect(current_user.user_option.reload.chat_channel_list_sort).to eq("recent_activity")
        end
      end

      it "temporarily shows all channels from the empty state and reapplies filters from the header" do
        drawer_page.visit_index
        drawer_page.channels_index.set_channel_filter("mentions")
        expect(drawer_page).to have_no_channel(channel_1)
        expect(drawer_page).to have_selector(
          ".empty-state__title",
          text: I18n.t("js.chat.channel_list.empty.filtered"),
        )

        drawer_page.channels_index.show_all_channels
        expect(drawer_page).to have_channel(channel_1)
        expect(drawer_page).to have_selector(".chat-channel-list-filter-toggle .d-icon-filter")

        drawer_page.channels_index.toggle_channel_filter
        expect(drawer_page).to have_no_channel(channel_1)
        expect(drawer_page).to have_selector(
          ".empty-state__title",
          text: I18n.t("js.chat.channel_list.empty.filtered"),
        )

        drawer_page.channels_index.toggle_channel_filter
        expect(drawer_page).to have_channel(channel_1)
        page.refresh
        chat.open_from_header
        expect(drawer_page.channels_index.component).to have_css(
          ".empty-state__title",
          text: I18n.t("js.chat.channel_list.empty.filtered"),
        )
        expect(drawer_page).to have_no_channel(channel_1)
      end

      it "filters the channel list from the shared options menu" do
        unread_channel = Fabricate(:category_channel, name: "unread channel")
        unread_channel.add(current_user)
        message = Fabricate(:chat_message, chat_channel: unread_channel, user: sender)
        unread_channel.update!(last_message: message, messages_count: 1)
        unread_channel.add(sender).mark_read!(message.id)

        drawer_page.visit_index

        expect(drawer_page).to have_channel(channel_1)
        expect(drawer_page).to have_unread_channel(unread_channel)

        drawer_page.channels_index.set_channel_filter("unread")

        expect(drawer_page).to have_no_channel(channel_1)
        expect(drawer_page).to have_channel(unread_channel)
      end
    end
  end

  context "when there are no channels" do
    it "shows separate empty states for Channels and Direct Messages" do
      drawer_page.visit_index
      expect(drawer_page).to have_selector(
        ".empty-state",
        text: I18n.t("js.chat.no_public_channels"),
      )

      drawer_page.click_direct_messages
      expect(drawer_page).to have_selector(
        ".empty-state",
        text: I18n.t("js.chat.no_direct_message_channels"),
      )
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
      fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }
      fab!(:dm_channel_4) do
        Fabricate(:direct_message_channel, users: [current_user, user_3], threading_enabled: true)
      end

      it "sorts unread direct messages before read and empty ones when priority is selected" do
        current_user.user_option.update!(chat_channel_list_sort_dms: "priority")
        self_dm = Fabricate(:direct_message_channel, users: [current_user])
        empty_dm =
          Fabricate(:direct_message_channel, users: [current_user, user_2], threading_enabled: true)

        older =
          Fabricate(:chat_message, chat_channel: dm_channel_2, user: user_1, created_at: 2.days.ago)
        recent =
          Fabricate(:chat_message, chat_channel: dm_channel_4, user: user_3, created_at: 1.day.ago)
        dm_channel_2.update!(last_message: older, messages_count: 1)
        dm_channel_4.update!(last_message: recent, messages_count: 1)
        dm_channel_2.membership_for(user_1).mark_read!(older.id)
        dm_channel_4.membership_for(user_3).mark_read!(recent.id)
        dm_channel_4.membership_for(current_user).mark_read!(recent.id)

        drawer_page.visit_index
        drawer_page.click_direct_messages

        expect(drawer_page).to have_channel(self_dm)
        expect(drawer_page).to have_channel(empty_dm)
        expect(drawer_page).to have_channel_at_position(dm_channel_2, 1)
        expect(drawer_page).to have_urgent_channel(dm_channel_2)
        expect(drawer_page).to have_channel_at_position(dm_channel_4, 2)
      end

      context "with unread threads" do
        fab!(:dm_channel_3) do
          Fabricate(:direct_message_channel, users: [current_user, user_2], threading_enabled: true)
        end
        fab!(:thread_1) do
          Fabricate(:chat_thread, channel: dm_channel_3, original_message_user: current_user)
        end
        fab!(:thread_2) do
          Fabricate(:chat_thread, channel: dm_channel_4, original_message_user: current_user)
        end

        before do
          [thread_1, thread_2].each do |thread|
            channel = thread.channel
            channel.update!(last_message_id: thread.original_message_id, messages_count: 1)
            channel.membership_for(current_user).mark_read!(thread.original_message_id)
            thread.membership_for(current_user).mark_read!(thread.original_message_id)
          end
        end

        it "sorts channels with unread threads by last reply" do
          current_user.user_option.update!(chat_channel_list_sort_dms: "recent_activity")

          drawer_page.visit_index
          drawer_page.click_direct_messages

          # Distinct timestamps: `use_service: true` stamps its own `created_at`
          # and the serializer truncates to whole seconds, so back-to-back
          # replies tie on recency and fall through to title order. They must
          # also land after the `mark_read!` above to still count as unread.
          freeze_time(1.minute.from_now) do
            Fabricate(:chat_message, thread: thread_1, user: user_2, use_service: true)
          end
          freeze_time(2.minutes.from_now) do
            Fabricate(:chat_message, thread: thread_2, user: user_3, use_service: true)
          end

          expect(drawer_page).to have_channel_at_position(dm_channel_4, 1)
          expect(drawer_page).to have_unread_channel(dm_channel_4)

          expect(drawer_page).to have_channel_at_position(dm_channel_3, 2)
          expect(drawer_page).to have_unread_channel(dm_channel_3)
        end

        it "sorts channels with unread threads by importance" do
          current_user.user_option.update!(chat_channel_list_sort_dms: "priority")

          drawer_page.visit_index
          drawer_page.click_direct_messages

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
end
