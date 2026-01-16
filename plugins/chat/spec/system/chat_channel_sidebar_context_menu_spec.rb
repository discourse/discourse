# frozen_string_literal: true

RSpec.describe "Chat channel sidebar context menu", type: :system do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_sidebar_page) { PageObjects::Pages::ChatSidebar.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when navigating to channel settings" do
    it "opens the channel settings page" do
      chat_page.visit_channel(channel_1)
      chat_sidebar_page.open_channel_settings(channel_1)
      expect(page).to have_current_path("/chat/c/#{channel_1.slug}/#{channel_1.id}/info/settings")
    end
  end

  context "when starring toggling starred channel" do
    it "stars and unstars a channel" do
      chat_page.visit_channel(channel_1)
      chat_sidebar_page.toggle_star_channel(channel_1)

      within(chat_sidebar_page.starred_section) do
        expect(page).to have_css(".channel-#{channel_1.id}")
      end
      expect(channel_1.membership_for(current_user).starred).to be_truthy

      chat_sidebar_page.toggle_star_channel(channel_1)

      expect(chat_sidebar_page).to have_no_starred_channels_section
      expect(channel_1.membership_for(current_user).starred).to be_falsy
    end
  end

  context "when leaving a channel" do
    fab!(:channel_2, :chat_channel)

    before { channel_2.add(current_user) }

    it "removes the channel from sidebar and redirects to another channel" do
      chat_page.visit_channel(channel_1)

      chat_sidebar_page.remove_channel(channel_1)

      expect(chat_sidebar_page).to have_no_channel(channel_1)
      expect(page).to have_current_path(chat.channel_path(channel_2.slug, channel_2.id))
    end

    context "when removing the last followed channel" do
      fab!(:dm_channel) do
        Fabricate(:direct_message_channel, users: [current_user, Fabricate(:user)])
      end

      before do
        channel_1.membership_for(current_user).update!(following: false)
        channel_2.membership_for(current_user).update!(following: false)
      end

      it "redirects to browse page" do
        chat_page.visit_channel(dm_channel)
        chat_sidebar_page.remove_channel(dm_channel)

        expect(chat_sidebar_page).to have_no_channel(dm_channel)
        expect(page).to have_current_path("/chat/browse/open")
      end
    end

    context "when removing a channel with another public channel available" do
      fab!(:dm_channel) do
        Fabricate(:direct_message_channel, users: [current_user, Fabricate(:user)])
      end

      before { channel_2.membership_for(current_user).update!(following: false) }

      it "redirects to the remaining public channel" do
        chat_page.visit_channel(dm_channel)
        chat_sidebar_page.remove_channel(dm_channel)

        expect(chat_sidebar_page).to have_no_channel(dm_channel)
        expect(page).to have_current_path(chat.channel_path(channel_1.slug, channel_1.id))
      end
    end

    context "when removing a group dm channel" do
      fab!(:group_dm_channel) do
        Fabricate(
          :direct_message_channel,
          users: [current_user, Fabricate(:user), Fabricate(:user)],
        )
      end

      it "removes the channel from sidebar but membership remains" do
        chat_page.visit_channel(group_dm_channel)
        chat_sidebar_page.remove_channel(group_dm_channel)

        expect(chat_sidebar_page).to have_no_channel(group_dm_channel)
        expect(group_dm_channel.membership_for(current_user)).to be_present
        expect(group_dm_channel.membership_for(current_user).following).to be_falsy
      end
    end
  end

  context "when changing notification settings" do
    it "changes notification level to never" do
      chat_page.visit_channel(channel_1)

      chat_sidebar_page.open_notification_settings(channel_1)
      chat_sidebar_page.set_notification_level("never")

      expect(channel_1.membership_for(current_user).reload.notification_level).to eq("never")
    end

    it "changes notification level to mention" do
      chat_page.visit_channel(channel_1)

      chat_sidebar_page.open_notification_settings(channel_1)
      chat_sidebar_page.set_notification_level("mention")

      expect(channel_1.membership_for(current_user).reload.notification_level).to eq("mention")
    end

    it "changes notification level to always" do
      channel_1.membership_for(current_user).update!(notification_level: "never")

      chat_page.visit_channel(channel_1)

      chat_sidebar_page.open_notification_settings(channel_1)
      chat_sidebar_page.set_notification_level("always")

      expect(channel_1.membership_for(current_user).reload.notification_level).to eq("always")
    end

    it "highlights the current notification level" do
      channel_1.membership_for(current_user).update!(notification_level: "mention")

      chat_page.visit_channel(channel_1)

      menu = chat_sidebar_page.open_notification_settings(channel_1)

      expect(menu).to have_option(
        ".chat-channel-sidebar-link-menu__notification-level-mention.-selected",
      )
    end
  end

  context "when muting and unmuting a channel" do
    it "mutes an unmuted channel" do
      chat_page.visit_channel(channel_1)

      chat_sidebar_page.open_notification_settings(channel_1)
      chat_sidebar_page.toggle_mute_channel

      expect(channel_1.membership_for(current_user).reload.muted).to eq(true)
    end

    it "unmutes a muted channel" do
      channel_1.membership_for(current_user).update!(muted: true)

      chat_page.visit_channel(channel_1)

      chat_sidebar_page.open_notification_settings(channel_1)
      chat_sidebar_page.toggle_mute_channel

      expect(channel_1.membership_for(current_user).reload.muted).to eq(false)
    end

    it "doesn't show unread indicators when channel is muted" do
      other_user = Fabricate(:user)
      channel_1.add(other_user)

      chat_page.visit_channel(channel_1)

      chat_sidebar_page.open_notification_settings(channel_1)
      chat_sidebar_page.toggle_mute_channel

      Fabricate(:chat_message_with_service, chat_channel: channel_1, user: other_user)

      expect(chat_sidebar_page).to have_no_unread_channel(channel_1)
    end
  end
end
