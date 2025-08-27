# frozen_string_literal: true

RSpec.describe "Channel notice", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  fab!(:current_user, :user)
  fab!(:user_1, :user)
  fab!(:user_2, :user)

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when mentioned user can't see the channel" do
    fab!(:secret_group, :group)
    fab!(:group_2) do
      Fabricate(
        :public_group,
        mentionable_level: Group::ALIAS_LEVELS[:everyone],
        members_visibility_level: 0, # everyone
        users: [user_1],
      )
    end
    fab!(:group_3) do
      Fabricate(
        :public_group,
        mentionable_level: Group::ALIAS_LEVELS[:everyone],
        members_visibility_level: 3, # staff
        users: [user_2],
      )
    end
    fab!(:private_category) { Fabricate(:private_category, group: secret_group) }
    fab!(:private_channel) { Fabricate(:chat_channel, chatable: private_category) }
    fab!(:mentioned_user, :user)

    before do
      secret_group.add(current_user)
      private_channel.add(current_user)
    end

    it "shows the notice" do
      chat_page.visit_channel(private_channel)
      channel_page.send_message("@#{mentioned_user.username} hello")

      expect(page).to have_selector(
        ".chat-notices__notice",
        text: I18n.t("chat.mention_warning.cannot_see", first_identifier: mentioned_user.username),
      )
    end

    it "does not expose group members when member visibility is restricted" do
      chat_page.visit_channel(private_channel)
      channel_page.send_message("hello @#{group_2.name} and @#{group_3.name}")

      expect(page).to have_selector(
        ".chat-notices__notice",
        text: I18n.t("chat.mention_warning.cannot_see_group", group_name: group_3.name),
      )
    end

    it "does not show group notice if unreachable member is not part of member visibility restricted group" do
      secret_group.add(user_2)

      chat_page.visit_channel(private_channel)
      channel_page.send_message("hello @#{group_2.name} and @#{group_3.name}")

      expect(page).to have_no_selector(
        ".chat-notices__notice",
        text: I18n.t("chat.mention_warning.cannot_see_group", group_name: group_3.name),
      )
    end

    context "when navigating away and back to the channel" do
      it "dismisses the notice" do
        chat_page.visit_channel(private_channel)
        channel_page.send_message("@#{mentioned_user.username} hello")
        expect(page).to have_css(".chat-notices__notice")
        find("#site-logo").click
        expect(page).to have_no_css("body.has-chat")
        find(".sidebar-row.channel-#{private_channel.id}").click
        expect(drawer_page).to have_open_channel(private_channel)

        wait_for_timeout(1000) # we are waiting for message bus to update the notice

        expect(page).to have_no_css(".chat-notices__notice", wait: 0)
      end
    end
  end
end
