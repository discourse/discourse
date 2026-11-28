# frozen_string_literal: true

RSpec.describe "List channels | mobile", mobile: true do
  fab!(:current_user, :user)

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channels_index) { PageObjects::Components::Chat::ChannelsIndex.new }
  let(:header) { PageObjects::Components::Chat::Header.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when channels present" do
    context "when category channels" do
      fab!(:category_channel_1, :category_channel)

      context "with a last message" do
        fab!(:message) do
          Fabricate(:chat_message, chat_channel: category_channel_1, user: current_user)
        end

        before do
          category_channel_1.update!(last_message: message, messages_count: 1)
          category_channel_1.add(current_user).mark_read!(message.id)
        end

        it "lists the public channel only on Channels and omits its message preview" do
          visit("/chat/direct-messages")
          expect(page).to have_css("#direct-message-channels")
          expect(channels_index).to have_no_channel(category_channel_1)

          find("#c-footer-channels").click
          expect(page).to have_current_path("/chat/channels")
          channel_row = PageObjects::Components::Chat::ChannelRow.new(category_channel_1.id)
          expect(channel_row.component).to have_no_css(".chat-channel__last-message")
        end
      end

      context "when member of the channel" do
        before { category_channel_1.add(current_user) }

        it "shows the channel in the correct section" do
          visit("/chat/channels")
          expect(page.find(".public-channels")).to have_content(category_channel_1.name)
        end
      end

      context "when not member of the channel" do
        it "doesn’t show the channel" do
          visit("/chat/channels")

          expect(page).to have_css("#public-channels .empty-state")
          expect(chat).to have_no_public_channel(category_channel_1)
        end
      end
    end

    context "when multiple category channels are present" do
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

      it "sorts channels alphabetically by default even with mentions and unreads" do
        Jobs.run_immediately!
        sender = Fabricate(:user)
        [channel_1, channel_2].each_with_index do |channel, index|
          message =
            Fabricate(
              :chat_message,
              chat_channel: channel,
              user: sender,
              created_at: (10 - 5 * index).minutes.ago,
            )
          channel.update!(last_message: message, messages_count: 1)
          channel.add(sender).mark_read!(message.id)
        end
        Fabricate(
          :chat_message_with_service,
          chat_channel: channel_4,
          message: "Hey @#{current_user.username}",
          user: sender,
        )

        read_message = Fabricate(:chat_message, chat_channel: channel_3, user: current_user)
        channel_3.update!(last_message: read_message, messages_count: 1)
        channel_3.membership_for(current_user).mark_read!(read_message.id)

        visit("/chat/channels")
        expect(channels_index).to have_unread_channel(channel_1)
        expect(channels_index).to have_unread_channel(channel_2)
        expect(channels_index).to have_unread_channel(channel_4, count: 1, urgent: true)

        expect(page.find("#public-channels a:nth-child(1)")["data-chat-channel-id"]).to eq(
          channel_1.id.to_s,
        )
        expect(page.find("#public-channels a:nth-child(2)")["data-chat-channel-id"]).to eq(
          channel_2.id.to_s,
        )
        expect(page.find("#public-channels a:nth-child(3)")["data-chat-channel-id"]).to eq(
          channel_3.id.to_s,
        )
        expect(page.find("#public-channels a:nth-child(4)")["data-chat-channel-id"]).to eq(
          channel_4.id.to_s,
        )
      end

      context "with emojis in title" do
        before do
          channel_1.update!(name: ":pear: a channel")
          channel_2.update!(name: ":apple: b channel")
        end

        it "sorts them by slug" do
          visit("/chat/channels")

          expect(page.find("#public-channels a:nth-child(1)")["data-chat-channel-id"]).to eq(
            channel_1.id.to_s,
          )
          expect(page.find("#public-channels a:nth-child(2)")["data-chat-channel-id"]).to eq(
            channel_2.id.to_s,
          )
        end
      end
    end

    context "when direct message channels" do
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }
      fab!(:inaccessible_dm_channel_1, :direct_message_channel)

      context "with a last message" do
        fab!(:message) { Fabricate(:chat_message, chat_channel: dm_channel_1, user: current_user) }

        before do
          dm_channel_1.update!(last_message: message, messages_count: 1)
          dm_channel_1.membership_for(current_user).mark_read!(message.id)
        end

        it "shows the last message" do
          visit("/chat/direct-messages")

          channel_row = PageObjects::Components::Chat::ChannelRow.new(dm_channel_1.id)
          expect(channel_row.component).to have_css(
            ".chat-channel__last-message",
            text: message.message,
          )
        end
      end

      context "when member of the channel" do
        it "shows the channel in the correct section" do
          visit("/chat/direct-messages")
          expect(page.find(".direct-message-channels")).to have_content(current_user.username)
        end
      end

      context "when not member of the channel" do
        it "doesn’t show the channel" do
          visit("/chat")
          find("#c-footer-direct-messages").click
          expect(page).to have_css("#direct-message-channels")
          expect(channels_index).to have_channel(dm_channel_1)
          expect(channels_index).to have_no_channel(inaccessible_dm_channel_1)
        end
      end
    end

    context "when long pressing a channel row" do
      fab!(:category_channel_1, :category_channel)

      let(:channel_row) { PageObjects::Components::Chat::ChannelRow.new(category_channel_1.id) }

      before { category_channel_1.add(current_user) }

      it "opens the channel menu on long press and lets the user leave" do
        visit("/chat/channels")

        channel_row.long_press
        expect(page).to have_css(".fk-d-menu-modal .chat-channel-sidebar-link-menu")

        find(".chat-channel-sidebar-link-menu__leave-channel").click

        expect(page).to have_current_path("/chat/browse/open")

        visit("/chat/channels")
        expect(find("#public-channels")).to have_no_css(
          channels_index.channel_row_selector(category_channel_1),
        )
      end

      it "changes the notification level from the menu submenu" do
        visit("/chat/channels")

        channel_row.long_press
        find(".chat-channel-sidebar-link-menu__open-notification-settings").click
        find(".chat-channel-sidebar-link-menu__notification-level-never").click

        expect(page).to have_no_css(".chat-channel-sidebar-link-menu__notification-level-never")
        expect(category_channel_1.membership_for(current_user).reload.notification_level).to eq(
          "never",
        )
      end

      context "when direct message channel" do
        fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

        let(:dm_channel_row) { PageObjects::Components::Chat::ChannelRow.new(dm_channel_1.id) }

        it "opens the channel menu" do
          visit("/chat/direct-messages")

          dm_channel_row.long_press

          expect(page).to have_css(".fk-d-menu-modal .chat-channel-sidebar-link-menu")
        end
      end
    end
  end

  context "when no category channels" do
    it "shows the empty channel list" do
      visit("/chat/channels")

      expect(page).to have_selector(".empty-state")
    end

    context "when user can create channels" do
      before { current_user.update!(admin: true) }

      it "shows the section" do
        visit("/chat/channels")
        expect(page).to have_css(".channels-list-container")
      end
    end
  end

  context "when no direct message channels" do
    it "shows the empty DM section and lets the user start a new DM from its options" do
      visit("/chat/direct-messages")
      expect(page).to have_selector(".channels-list-container")

      find(".chat-channel-list-options-button").click
      find('[data-menu-option-id="startDm"]').click

      expect(chat.message_creator).to be_opened
    end
  end

  context "when chat disabled" do
    before { SiteSetting.chat_enabled = false }

    it "doesn’t show the sections" do
      visit("/chat")
      expect(header).to have_no_chat_button
      expect(page).to have_no_css(".channels-list-container")
    end
  end

  context "when user has chat disabled" do
    before { current_user.user_option.update!(chat_enabled: false) }

    it "shows the disabled screen instead of channel lists" do
      visit("/chat")
      expect(page).to have_css(".chat-disabled")
      expect(page).to have_no_css(".channels-list-container")
    end
  end

  context "when chat_preferred_index is set to direct_messages" do
    before { SiteSetting.chat_preferred_index = "direct_messages" }

    it "changes the default index" do
      visit("/chat")

      expect(page).to have_current_path("/chat/direct-messages")
    end

    context "when user can't use direct messages" do
      before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:staff] }

      it "redirects to browse" do
        visit("/chat")

        expect(page).to have_current_path("/chat/browse/open")
      end
    end
  end

  context "when chat_preferred_index is not set" do
    it "redirects to channels" do
      visit("/chat")

      expect(page).to have_current_path("/chat/channels")
    end
  end

  context "when chat_preferred_index is set to my_threads" do
    before do
      SiteSetting.chat_threads_enabled = true
      SiteSetting.chat_preferred_index = "my_threads"
    end

    context "when user has viewable threads" do
      it "redirects to threads" do
        channel = Fabricate(:chat_channel, threading_enabled: true)
        channel.add(current_user)
        other_user = Fabricate(:user)
        channel.add(other_user)

        thread = Fabricate(:chat_thread, channel: channel, original_message_user: current_user)
        reply = Fabricate(:chat_message, chat_channel: channel, thread: thread, user: other_user)
        channel.update!(last_message_id: thread.original_message_id, messages_count: 1)
        channel.membership_for(current_user).mark_read!(thread.original_message_id)
        thread.add(current_user).mark_read!(thread.original_message_id)
        thread.add(other_user).mark_read!(reply.id)
        thread.update_last_message_id!
        thread.set_replies_count_cache(1, update_db: true)

        visit("/chat")

        expect(page).to have_current_path("/chat/threads")
      end
    end

    context "when user has no viewable threads" do
      it "redirects to browse" do
        channel = Fabricate(:chat_channel, threading_enabled: true)
        channel.add(current_user)

        visit("/chat")

        expect(page).to have_current_path("/chat/browse/open")
      end
    end

    context "when threads feature is disabled" do
      before { SiteSetting.chat_threads_enabled = false }

      it "redirects to browse" do
        visit("/chat")

        expect(page).to have_current_path("/chat/browse/open")
      end
    end
  end
end
