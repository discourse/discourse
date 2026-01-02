# frozen_string_literal: true

RSpec.describe "Shortcuts | sidebar", type: :system do
  fab!(:current_user, :admin)

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:sidebar_page) { PageObjects::Pages::ChatSidebar.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when using Alt+Up/Down arrows" do
    fab!(:channel_1, :chat_channel)
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

    before { channel_1.add(current_user) }

    context "when on homepage" do
      it "does nothing" do
        visit("/")
        find("body").send_keys(%i[alt down])

        expect(sidebar_page).to have_no_active_channel(channel_1)
        expect(sidebar_page).to have_no_active_channel(dm_channel_1)
      end
    end

    context "when on chat page" do
      it "navigates through the channels" do
        chat.visit_channel(channel_1)
        expect(sidebar_page).to have_active_channel(channel_1)

        find("body").send_keys(%i[alt down])

        expect(sidebar_page).to have_active_channel(dm_channel_1)

        find("body").send_keys(%i[alt down])

        expect(sidebar_page).to have_active_channel(channel_1)

        find("body").send_keys(%i[alt up])

        expect(sidebar_page).to have_active_channel(dm_channel_1)
      end
    end

    context "when there are starred channels" do
      fab!(:alpha_channel) { Fabricate(:chat_channel, name: "Alpha Channel") }
      fab!(:beta_channel) { Fabricate(:chat_channel, name: "Beta Channel") }
      fab!(:other_user, :user)
      fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [current_user, other_user]) }

      before do
        # Unfollow channel_1 from parent context to make tests independent
        channel_1.membership_for(current_user).update!(following: false)
        alpha_channel.add(current_user)
        beta_channel.add(current_user)
      end

      it "navigates through starred, then public, then DMs in sidebar order" do
        # Star a DM channel - this should appear in the starred section (before public channels)
        dm_channel_1.membership_for(current_user).update!(starred: true)

        chat.visit_channel(dm_channel_1)
        expect(sidebar_page).to have_active_channel(dm_channel_1)

        # Alt+Down: starred DM -> first unstarred public channel (alpha_channel)
        find("body").send_keys(%i[alt down])
        expect(sidebar_page).to have_active_channel(alpha_channel)

        # Alt+Down: alpha_channel -> beta_channel
        find("body").send_keys(%i[alt down])
        expect(sidebar_page).to have_active_channel(beta_channel)

        # Alt+Down: beta_channel -> unstarred DM (dm_channel_2)
        find("body").send_keys(%i[alt down])
        expect(sidebar_page).to have_active_channel(dm_channel_2)

        # Alt+Down: dm_channel_2 -> wrap to starred (dm_channel_1)
        find("body").send_keys(%i[alt down])
        expect(sidebar_page).to have_active_channel(dm_channel_1)

        # Alt+Up: starred DM -> wrap to last unstarred DM
        find("body").send_keys(%i[alt up])
        expect(sidebar_page).to have_active_channel(dm_channel_2)
      end

      it "navigates correctly when a public channel is starred" do
        # Star alpha_channel - it should appear in the starred section
        alpha_channel.membership_for(current_user).update!(starred: true)

        chat.visit_channel(alpha_channel)
        expect(sidebar_page).to have_active_channel(alpha_channel)

        # Alt+Down: starred public -> unstarred public (beta_channel)
        find("body").send_keys(%i[alt down])
        expect(sidebar_page).to have_active_channel(beta_channel)

        # Alt+Down: beta_channel -> dm_channel_1
        find("body").send_keys(%i[alt down])
        expect(sidebar_page).to have_active_channel(dm_channel_1)

        # Alt+Down: dm_channel_1 -> dm_channel_2
        find("body").send_keys(%i[alt down])
        expect(sidebar_page).to have_active_channel(dm_channel_2)

        # Alt+Down: dm_channel_2 -> wrap to starred (alpha_channel)
        find("body").send_keys(%i[alt down])
        expect(sidebar_page).to have_active_channel(alpha_channel)
      end
    end
  end

  context "when using Alt+Shift+Up/Down arrows" do
    fab!(:channel_1) { Fabricate(:chat_channel, name: "Channel 1") }
    fab!(:channel_2) { Fabricate(:chat_channel, name: "Channel 2") }
    fab!(:channel_3) { Fabricate(:chat_channel, name: "Channel 3") }
    fab!(:channel_4) { Fabricate(:chat_channel, name: "Channel 4") }
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }
    fab!(:other_user, :user)
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [current_user, other_user]) }

    before do
      channel_1.add(current_user)
      channel_2.add(current_user)
      channel_3.add(current_user)
      channel_4.add(current_user)
    end

    context "when on homepage" do
      it "does nothing" do
        visit("/")
        find("body").send_keys(%i[alt shift down])

        expect(sidebar_page).to have_no_active_channel(channel_1)
        expect(sidebar_page).to have_no_active_channel(channel_2)
        expect(sidebar_page).to have_no_active_channel(dm_channel_1)
        expect(sidebar_page).to have_no_active_channel(dm_channel_2)
      end
    end

    context "when on chat page" do
      it "does nothing when no channels have activity" do
        chat.visit_channel(channel_1)
        expect(sidebar_page).to have_active_channel(channel_1)

        find("body").send_keys(%i[alt shift down])

        expect(sidebar_page).to have_active_channel(channel_1)

        find("body").send_keys(%i[alt shift down])

        expect(sidebar_page).to have_active_channel(channel_1)

        find("body").send_keys(%i[alt shift up])

        expect(sidebar_page).to have_active_channel(channel_1)
      end

      it "navigates through the channels with activity" do
        chat.visit_channel(channel_1)
        expect(sidebar_page).to have_active_channel(channel_1)

        Fabricate(:chat_message, chat_channel: channel_2, message: "hello!", use_service: true)
        expect(sidebar_page).to have_unread_channel(channel_2)

        Fabricate(
          :chat_message,
          chat_channel: dm_channel_2,
          message: "hello here!",
          use_service: true,
        )
        expect(sidebar_page).to have_unread_channel(dm_channel_2)

        find("body").send_keys(%i[alt shift down])

        expect(sidebar_page).to have_active_channel(channel_2)
        expect(sidebar_page).to have_no_unread_channel(channel_2)

        find("body").send_keys(%i[alt shift down])

        expect(sidebar_page).to have_active_channel(dm_channel_2)
        expect(sidebar_page).to have_no_unread_channel(dm_channel_2)

        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          message: "hello again!",
          use_service: true,
        )
        expect(sidebar_page).to have_unread_channel(channel_1)

        find("body").send_keys(%i[alt shift up])

        expect(sidebar_page).to have_active_channel(channel_1)
        expect(sidebar_page).to have_no_unread_channel(channel_1)

        Fabricate(:chat_message, chat_channel: dm_channel_1, message: "bye now!", use_service: true)
        expect(sidebar_page).to have_unread_channel(dm_channel_1)

        find("body").send_keys(%i[alt shift up])

        expect(sidebar_page).to have_active_channel(dm_channel_1)
        expect(sidebar_page).to have_no_unread_channel(dm_channel_1)
      end

      it "remembers where the current channel is, even if that channel is unread" do
        chat.visit_channel(channel_3)
        expect(sidebar_page).to have_active_channel(channel_3)

        Fabricate(:chat_message, chat_channel: channel_2, message: "hello!", use_service: true)
        expect(sidebar_page).to have_unread_channel(channel_2)

        Fabricate(:chat_message, chat_channel: channel_4, message: "yes, hello!", use_service: true)
        expect(sidebar_page).to have_unread_channel(channel_4)

        find("body").send_keys(%i[alt shift down])

        expect(sidebar_page).to have_active_channel(channel_4)
        expect(sidebar_page).to have_no_unread_channel(channel_4)

        Fabricate(
          :chat_message,
          chat_channel: channel_3,
          message: "hello, here, too!",
          use_service: true,
        )
        expect(sidebar_page).to have_unread_channel(channel_3)

        find("body").send_keys(%i[alt shift up])

        expect(sidebar_page).to have_active_channel(channel_3)
        expect(sidebar_page).to have_no_unread_channel(channel_3)

        Fabricate(
          :chat_message,
          chat_channel: channel_4,
          message: "okay, byebye!",
          use_service: true,
        )
        expect(sidebar_page).to have_unread_channel(channel_4)

        find("body").send_keys(%i[alt shift up])

        expect(sidebar_page).to have_active_channel(channel_2)
        expect(sidebar_page).to have_no_unread_channel(channel_2)
      end

      it "handles the shortcut being pressed quickly" do
        chat.visit_channel(channel_2)
        expect(sidebar_page).to have_active_channel(channel_2)

        Fabricate(:chat_message, chat_channel: channel_1, message: "hello!", use_service: true)
        expect(sidebar_page).to have_unread_channel(channel_1)

        Fabricate(:chat_message, chat_channel: channel_4, message: "howdy!", use_service: true)
        expect(sidebar_page).to have_unread_channel(channel_4)

        find("body").send_keys(%i[alt shift up])
        find("body").send_keys(%i[alt shift down])

        expect(sidebar_page).to have_active_channel(channel_4)
      end
    end
  end
end
