# frozen_string_literal: true

RSpec.describe "Shortcuts | sidebar", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when using Alt+Up/Down arrows" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

    before { channel_1.add(current_user) }

    context "when on homepage" do
      it "does nothing" do
        visit("/")
        find("body").send_keys(%i[alt arrow_down])

        expect(sidebar_page).to have_no_active_channel(channel_1)
        expect(sidebar_page).to have_no_active_channel(dm_channel_1)
      end
    end

    context "when on chat page" do
      it "navigates through the channels" do
        chat.visit_channel(channel_1)
        expect(sidebar_page).to have_active_channel(channel_1)

        find("body").send_keys(%i[alt arrow_down])

        expect(sidebar_page).to have_active_channel(dm_channel_1)

        find("body").send_keys(%i[alt arrow_down])

        expect(sidebar_page).to have_active_channel(channel_1)

        find("body").send_keys(%i[alt arrow_up])

        expect(sidebar_page).to have_active_channel(dm_channel_1)
      end
    end
  end

  context "when using Alt+Shift+Up/Down arrows" do
    fab!(:channel_1) { Fabricate(:chat_channel, name: "Channel 1") }
    fab!(:channel_2) { Fabricate(:chat_channel, name: "Channel 2") }
    fab!(:channel_3) { Fabricate(:chat_channel, name: "Channel 3") }
    fab!(:channel_4) { Fabricate(:chat_channel, name: "Channel 4") }
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }
    fab!(:other_user) { Fabricate(:user) }
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
        find("body").send_keys(%i[alt shift arrow_down])

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

        find("body").send_keys(%i[alt shift arrow_down])

        expect(sidebar_page).to have_active_channel(channel_1)

        find("body").send_keys(%i[alt shift arrow_down])

        expect(sidebar_page).to have_active_channel(channel_1)

        find("body").send_keys(%i[alt shift arrow_up])

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

        find("body").send_keys(%i[alt shift arrow_down])

        expect(sidebar_page).to have_active_channel(channel_2)
        expect(sidebar_page).to have_no_unread_channel(channel_2)

        find("body").send_keys(%i[alt shift arrow_down])

        expect(sidebar_page).to have_active_channel(dm_channel_2)
        expect(sidebar_page).to have_no_unread_channel(dm_channel_2)

        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          message: "hello again!",
          use_service: true,
        )
        expect(sidebar_page).to have_unread_channel(channel_1)

        find("body").send_keys(%i[alt shift arrow_up])

        expect(sidebar_page).to have_active_channel(channel_1)
        expect(sidebar_page).to have_no_unread_channel(channel_1)

        Fabricate(:chat_message, chat_channel: dm_channel_1, message: "bye now!", use_service: true)
        expect(sidebar_page).to have_unread_channel(dm_channel_1)

        find("body").send_keys(%i[alt shift arrow_up])

        expect(sidebar_page).to have_active_channel(dm_channel_1)
        expect(sidebar_page).to have_no_unread_channel(dm_channel_1)
      end

      it "remembers where the current channel is, even if that channel is unread" do
        chat.visit_channel(channel_3)
        expect(sidebar_page).to have_active_channel(channel_3)

        Fabricate(:chat_message, chat_channel: channel_2, message: "hello!", use_service: true)
        expect(sidebar_page).to have_unread_channel(channel_2)

        Fabricate(:chat_message, chat_channel: channel_4, message: "hello!", use_service: true)
        expect(sidebar_page).to have_unread_channel(channel_4)

        find("body").send_keys(%i[alt shift arrow_down])

        expect(sidebar_page).to have_active_channel(channel_4)
        expect(sidebar_page).to have_no_unread_channel(channel_4)
      end
    end
  end
end
