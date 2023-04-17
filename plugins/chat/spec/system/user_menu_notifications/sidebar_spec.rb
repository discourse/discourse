# frozen_string_literal: true

RSpec.describe "User menu notifications | sidebar", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
    sign_in(current_user)
  end

  shared_examples "chat not available" do
    it "doesn’t show the chat tab" do
      visit("/")
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

      context "when @username" do
        it "shows a mention notification" do
          Jobs.run_immediately!

          message =
            Chat::MessageCreator.create(
              chat_channel: dm_channel_1,
              user: other_user,
              content: "this is fine @#{current_user.username}",
            ).chat_message

          visit("/")

          find(".header-dropdown-toggle.current-user").click
          within("#user-menu-button-chat-notifications") do |panel|
            expect(panel).to have_content(1)
            panel.click
          end
          expect(find("#quick-access-chat-notifications")).to have_link(
            I18n.t("js.notifications.popup.direct_message_chat_mention.direct"),
            href: "/chat/c/#{other_user.username}/#{dm_channel_1.id}/#{message.id}",
          )
        end
      end
    end

    context "when category channel" do
      fab!(:channel_1) { Fabricate(:chat_channel) }

      before do
        channel_1.add(current_user)
        channel_1.add(other_user)
        # Jobs.run_immediately!
      end

      context "when group mention" do
        fab!(:group) { Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone]) }

        before { group.add(current_user) }

        xit "shows a group mention notification" do
          message =
            Chat::MessageCreator.create(
              chat_channel: channel_1,
              user: other_user,
              content: "this is fine @#{group.name}",
            ).chat_message

          visit("/")

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
            href: "/chat/c/#{channel_1.slug}/#{channel_1.id}/#{message.id}",
          )
        end
      end

      context "when @username" do
        it "shows a mention notification" do
          Jobs.run_immediately!

          message =
            Chat::MessageCreator.create(
              chat_channel: channel_1,
              user: other_user,
              content: "this is fine @#{current_user.username}",
            ).chat_message

          visit("/")

          find(".header-dropdown-toggle.current-user").click
          within("#user-menu-button-chat-notifications") do |panel|
            expect(panel).to have_content(1)
            panel.click
          end

          expect(find("#quick-access-chat-notifications")).to have_link(
            I18n.t("js.notifications.popup.chat_mention.direct", channel: channel_1.name),
            href: "/chat/c/#{channel_1.slug}/#{channel_1.id}/#{message.id}",
          )
        end
      end

      context "when @all" do
        xit "shows a mention notification" do
          message =
            Chat::MessageCreator.create(
              chat_channel: channel_1,
              user: other_user,
              content: "this is fine @all",
            ).chat_message

          visit("/")

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
            href: "/chat/c/#{channel_1.slug}/#{channel_1.id}/#{message.id}",
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
        visit("/")
        find(".header-dropdown-toggle.current-user").click

        expect(find("#user-menu-button-chat-notifications")).to have_content(1)
        expect(find("#quick-access-all-notifications")).to have_css(".chat-invitation.unread")
      end
    end
  end
end
