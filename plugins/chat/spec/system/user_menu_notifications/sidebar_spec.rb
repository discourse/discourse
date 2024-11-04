# frozen_string_literal: true

RSpec.describe "User menu notifications | sidebar", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
    sign_in(current_user)
    set_subfolder "/discuss"
  end

  shared_examples "chat not available" do
    it "doesn’t show the chat tab" do
      visit("/discuss")
      find(".header-dropdown-toggle.current-user").click

      expect(page).to have_no_css("#user-menu-button-chat-notifications")
    end
  end

  context "when chat is disabled" do
    before { SiteSetting.chat_enabled = false }

    include_examples "chat not available"
  end

  context "when user has chat disabled" do
    before { current_user.user_option.update!(chat_enabled: false) }

    include_examples "chat not available"
  end

  context "when mentioning" do
    fab!(:other_user) { Fabricate(:user) }

    context "when dm channel" do
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, other_user]) }

      before { Jobs.run_immediately! }

      context "when @username" do
        let!(:message) do
          Fabricate(
            :chat_message,
            chat_channel: dm_channel_1,
            user: other_user,
            message: "this is fine @#{current_user.username}",
            use_service: true,
          )
        end

        it "shows a mention notification" do
          visit("/discuss")

          find(".header-dropdown-toggle.current-user").click
          within("#user-menu-button-chat-notifications") do |panel|
            expect(panel).to have_content(1)
            panel.click
          end
          expect(find("#quick-access-chat-notifications")).to have_link(
            I18n.t("js.notifications.popup.direct_message_chat_mention.direct"),
            href: "/discuss/chat/c/-/#{dm_channel_1.id}/#{message.id}",
          )
        end
      end
    end

    context "when category channel" do
      fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }

      before do
        Jobs.run_immediately!
        channel_1.add(current_user)
        channel_1.add(other_user)
      end

      context "when group mention" do
        fab!(:group) { Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone]) }

        let(:message) do
          Fabricate(
            :chat_message,
            chat_channel: channel_1,
            user: other_user,
            message: "this is fine @#{group.name}",
            use_service: true,
          )
        end

        before do
          group.add(current_user)
          message
        end

        it "shows a group mention notification" do
          visit("/discuss")

          find(".header-dropdown-toggle.current-user").click
          within("#user-menu-button-chat-notifications") do |panel|
            expect(panel).to have_content(1)
            panel.click
          end
          expect(find("#quick-access-chat-notifications")).to have_link(
            I18n.t(
              "js.notifications.popup.chat_mention.other_plain",
              identifier: "@#{group.name}",
              channel: channel_1.name,
            ),
            href: "/discuss/chat/c/#{channel_1.slug}/#{channel_1.id}/#{message.id}",
          )
        end
      end

      context "when @username" do
        let!(:message) do
          Fabricate(
            :chat_message,
            chat_channel: channel_1,
            user: other_user,
            message: "this is fine @#{current_user.username}",
            use_service: true,
          )
        end

        it "shows a mention notification" do
          visit("/discuss")

          find(".header-dropdown-toggle.current-user").click
          within("#user-menu-button-chat-notifications") do |panel|
            expect(panel).to have_content(1)
            panel.click
          end

          expect(find("#quick-access-chat-notifications")).to have_link(
            I18n.t("js.notifications.popup.chat_mention.direct", channel: channel_1.name),
            href: "/discuss/chat/c/#{channel_1.slug}/#{channel_1.id}/#{message.id}",
          )
        end

        context "when the message is in a thread" do
          let!(:message) do
            Fabricate(
              :chat_message,
              thread: Fabricate(:chat_thread, channel: channel_1),
              user: other_user,
              message: "this is fine @#{current_user.username}",
              use_service: true,
            )
          end

          it "shows a mention notification when the message is in a thread" do
            visit("/discuss")

            find(".header-dropdown-toggle.current-user").click
            within("#user-menu-button-chat-notifications") do |panel|
              expect(panel).to have_content(1)
              panel.click
            end

            expect(find("#quick-access-chat-notifications")).to have_link(
              I18n.t("js.notifications.popup.chat_mention.direct", channel: channel_1.name),
              href: "/discuss/chat/c/#{channel_1.slug}/#{channel_1.id}/t/#{message.thread_id}",
            )
          end
        end
      end

      context "when @all" do
        let!(:message) do
          Fabricate(
            :chat_message,
            chat_channel: channel_1,
            user: other_user,
            message: "this is fine @all",
            use_service: true,
          )
        end

        it "shows a mention notification" do
          visit("/discuss")

          find(".header-dropdown-toggle.current-user").click
          within("#user-menu-button-chat-notifications") do |panel|
            expect(panel).to have_content(1)
            panel.click
          end

          expect(find("#quick-access-chat-notifications")).to have_link(
            I18n.t(
              "js.notifications.popup.chat_mention.other_plain",
              identifier: "@all",
              channel: channel_1.name,
            ),
            href: "/discuss/chat/c/#{channel_1.slug}/#{channel_1.id}/#{message.id}",
          )
        end
      end
    end
  end

  context "when inviting a user" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:other_user) { Fabricate(:user) }

    before { channel_1.add(current_user) }

    xit "shows an invitation notification" do
      Jobs.run_immediately!

      chat.visit_channel(channel_1)
      channel.send_message("this is fine @#{other_user.username}")
      find(".invite-link", wait: 5).click

      using_session(:user_1) do
        sign_in(other_user)
        visit("/discuss")
        find(".header-dropdown-toggle.current-user").click

        expect(find("#user-menu-button-chat-notifications")).to have_content(1)
        expect(find("#quick-access-all-notifications")).to have_css(".chat-invitation.unread")
      end
    end
  end
end
