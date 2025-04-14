# frozen_string_literal: true

RSpec.describe "Channel - Info - Members page", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  before do
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "as unauthorized user" do
    before { SiteSetting.chat_allowed_groups = Fabricate(:group).id }

    it "can't see channel members" do
      chat_page.visit_channel_members(channel_1)

      expect(page).to have_current_path("/latest")
    end
  end

  context "as authorized user" do
    context "with no members" do
      it "redirects to settings page" do
        chat_page.visit_channel_members(channel_1)

        expect(page).to have_current_path("/chat/c/#{channel_1.slug}/#{channel_1.id}/info/members")
      end
    end

    context "with members" do
      before do
        channel_1.add(current_user)
        channel_1.add(Fabricate(:user, username: "cat"))
        98.times { channel_1.add(Fabricate(:user)) }
        Jobs.run_immediately!
        channel_1.update!(user_count_stale: true)
        Jobs::Chat::UpdateChannelUserCount.new.execute(chat_channel_id: channel_1.id)
      end

      xit "shows all members" do
        chat_page.visit_channel_members(channel_1)

        expect(page).to have_selector(".c-channel-members__list-item", count: 60)

        scroll_to(find(".c-channel-members__list-item:nth-child(60)"))

        expect(page).to have_selector(".c-channel-members__list-item", count: 100)

        scroll_to(find(".c-channel-members__list-item:nth-child(100)"))

        expect(page).to have_selector(".c-channel-members__list-item", count: 100)
      end

      context "with filter" do
        it "filters members" do
          chat_page.visit_channel_members(channel_1)
          find(".c-channel-members__filter").fill_in(with: "cat")

          expect(page).to have_selector(
            ".c-channel-members__list-item .-user-info",
            count: 1,
            text: "cat",
          )
        end
      end

      context "with user status" do
        xit "renders status next to name" do
          SiteSetting.enable_user_status = true
          current_user.set_status!("walking the dog", "dog")

          chat_page.visit_channel_members(channel_1)

          expect(page).to have_selector(
            ".-member .user-status-message img[alt='#{current_user.user_status.emoji}']",
          )
        end
      end
    end
  end

  context "when category channel" do
    it "doesn’t allow to add members" do
      chat_page.visit_channel_members(channel_1)

      expect(chat_page).to have_no_css(".c-channel-members__list-item.-add-member")
    end
  end

  context "when group DM channel" do
    fab!(:channel_1) do
      Fabricate(
        :direct_message_channel,
        slug: "test-channel",
        users: [current_user, Fabricate(:user), Fabricate(:user)],
        group: true,
      )
    end

    it "allows to add members" do
      new_user = Fabricate(:user)
      chat_page.visit_channel_members(channel_1)
      chat_page.find(".c-channel-members__list-item.-add-member").click
      chat_page.find(".chat-message-creator__members-input").fill_in(with: new_user.username)
      chat_page.find(".chat-message-creator__list-item").click
      chat_page.find(".add-to-channel").click

      expect(chat_page).to have_current_path("/chat/c/#{channel_1.slug}/#{channel_1.id}")
      expect(chat_page).to have_text(
        :all,
        I18n.t(
          "chat.channel.users_invited_to_channel",
          invited_users: "@#{new_user.username}",
          inviting_user: "@#{current_user.username}",
          count: 1,
        ),
      )
    end
  end

  context "when 1:1 DM channel" do
    fab!(:channel_1) do
      Fabricate(
        :direct_message_channel,
        slug: "test-channel",
        users: [current_user, Fabricate(:user)],
        group: false,
      )
    end

    it "allows to add members when there are no channel messages" do
      new_user = Fabricate(:user)

      chat_page.visit_channel_members(channel_1)
      expect(chat_page).to have_add_member_button

      chat_page.find(".c-channel-members__list-item.-add-member").click
      chat_page.find(".chat-message-creator__members-input").fill_in(with: new_user.username)
      chat_page.find(".chat-message-creator__list-item").click
      chat_page.find(".add-to-channel").click

      expect(chat_page).to have_current_path("/chat/c/#{channel_1.slug}/#{channel_1.id}")
      expect(chat_page).to have_text(
        :all,
        I18n.t(
          "chat.channel.users_invited_to_channel",
          invited_users: "@#{new_user.username}",
          inviting_user: "@#{current_user.username}",
          count: 1,
        ),
      )

      chat_page.visit_channel_members(channel_1)
      expect(chat_page).to have_no_add_member_button
    end
  end

  describe "removing members" do
    fab!(:current_user) { Fabricate(:admin) }

    before { channel_1.add(Fabricate(:user)) }

    context "when the channel is a category channel" do
      it "allows removing members" do
        chat_page.visit_channel_members(channel_1)

        expect(chat_page).to have_css(".c-channel-members__list-item .-remove-member")
      end
    end

    context "when the channel is a group DM" do
      fab!(:channel_1) do
        Fabricate(
          :direct_message_channel,
          slug: "test-channel",
          users: [current_user, Fabricate(:user), Fabricate(:user)],
          group: true,
        )
      end

      it "allows removing members" do
        chat_page.visit_channel_members(channel_1)

        expect(chat_page).to have_css(".c-channel-members__list-item .-remove-member")
      end
    end

    context "when the channel is a one-on-one DM" do
      fab!(:channel_1) do
        Fabricate(
          :direct_message_channel,
          slug: "test-channel",
          users: [current_user, Fabricate(:user)],
          group: false,
        )
      end

      it "does not allow removing members" do
        chat_page.visit_channel_members(channel_1)

        expect(chat_page).to have_no_css(".c-channel-members__list-item .-remove-member")
      end
    end
  end

  context "when on mobile", mobile: true do
    it "has a link to the settings" do
      chat_page.visit_channel_members(channel_1)

      expect(page).to have_css(
        ".c-back-button[href='/chat/c/#{channel_1.slug}/#{channel_1.id}/info/settings']",
      )
    end
  end
end
