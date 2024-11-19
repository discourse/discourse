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

        expect(page).to have_no_selector(".channel-#{channel_1.id}.active")
        expect(page).to have_no_selector(".channel-#{dm_channel_1.id}.active")
      end
    end

    context "when on chat page" do
      it "navigates through the channels" do
        chat.visit_channel(channel_1)

        expect(page).to have_selector(".channel-#{channel_1.id}.active")

        find("body").send_keys(%i[alt arrow_down])

        expect(page).to have_selector(".channel-#{dm_channel_1.id}.active")

        find("body").send_keys(%i[alt arrow_down])

        expect(page).to have_selector(".channel-#{channel_1.id}.active")

        find("body").send_keys(%i[alt arrow_up])

        expect(page).to have_selector(".channel-#{dm_channel_1.id}.active")
      end
    end
  end

  context "when using Alt+Shift+Up/Down arrows" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:channel_2) { Fabricate(:chat_channel) }
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [current_user]) }

    before do
      channel_1.add(current_user)
      channel_2.add(current_user)
    end

    context "when on homepage" do
      it "does nothing" do
        visit("/")
        find("body").send_keys(%i[alt shift arrow_down])

        expect(page).to have_no_selector(".channel-#{channel_1.id}.active")
        expect(page).to have_no_selector(".channel-#{channel_2.id}.active")
        expect(page).to have_no_selector(".channel-#{dm_channel_1.id}.active")
        expect(page).to have_no_selector(".channel-#{dm_channel_2.id}.active")
      end
    end

    context "when on chat page" do
      it "does nothing when no channels have activity" do
        chat.visit_channel(channel_1)

        expect(page).to have_selector(".channel-#{channel_1.id}.active")

        find("body").send_keys(%i[alt shift arrow_down])

        expect(page).to have_selector(".channel-#{channel_1.id}.active")

        find("body").send_keys(%i[alt shift arrow_down])

        expect(page).to have_selector(".channel-#{channel_1.id}.active")

        find("body").send_keys(%i[alt shift arrow_up])

        expect(page).to have_selector(".channel-#{channel_1.id}.active")
      end

      it "navigates through the channels with activity" do
        Fabricate(:chat_message, chat_channel: channel_2, message: "hello!", use_service: true)

        Fabricate(
          :chat_message,
          chat_channel: dm_channel_2,
          message: "hello here!",
          use_service: true,
        )

        chat.visit_channel(channel_1)

        expect(page).to have_selector(".channel-#{channel_1.id}.active")

        find("body").send_keys(%i[alt shift arrow_down])

        expect(page).to have_selector(".channel-#{channel_2.id}.active")

        find("body").send_keys(%i[alt shift arrow_down])

        expect(page).to have_selector(".channel-#{dm_channel_2.id}.active")

        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          message: "hello again!",
          use_service: true,
        )

        find("body").send_keys(%i[alt shift arrow_up])

        expect(page).to have_selector(".channel-#{channel_1.id}.active")

        Fabricate(:chat_message, chat_channel: dm_channel_1, message: "bye now!", use_service: true)

        find("body").send_keys(%i[alt shift arrow_up])

        expect(page).to have_selector(".channel-#{dm_channel_1.id}.active")
      end

      it "remembers where the current channel is, even if that channel is unread" do
        chat.visit_channel(channel_2)
        expect(sidebar_page).to have_active_channel(channel_2)

        Fabricate(:chat_message, chat_channel: channel_1, message: "hello!", use_service: true)
        expect(sidebar_page).to have_unread_channel(channel_1)

        Fabricate(:chat_message, chat_channel: channel_3, message: "hello!", use_service: true)
        expect(sidebar_page).to have_unread_channel(channel_3)

        find("body").send_keys(%i[alt shift arrow_down])

        expect(sidebar_page).to have_active_channel(channel_3)
        expect(sidebar_page).to have_no_unread_channel(channel_3)
      end
    end
  end
end
