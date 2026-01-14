# frozen_string_literal: true

describe "Viewing user private messages", type: :system do
  fab!(:user) { Fabricate(:user, username: "mIxed_caSE_usERNAME") }
  fab!(:user2, :user)

  let(:user_private_messages_page) { PageObjects::Pages::UserPrivateMessages.new }

  before { sign_in(user) }

  describe "when the user has group messages" do
    fab!(:group) do
      Fabricate(:group, name: "miXeD_caSE_name", has_messages: true).tap { |g| g.add(user) }
    end

    before { SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:everyone] }

    it "allows the user to view the default messages inbox" do
      user_private_messages_page.visit(user)

      expect(user_private_messages_page).to have_right_inbox_dropdown_value("Inbox")
    end

    it "allows the user to view the group messages inbox of a group" do
      user_private_messages_page.visit_group_inbox(user, group)

      expect(user_private_messages_page).to have_right_inbox_dropdown_value("miXeD_caSE_name")
    end

    context "when user has unread messages" do
      fab!(:pm_topic) { Fabricate(:private_message_topic, user: user2, recipient: user) }

      it "shows unread icon in inbox dropdown trigger and dropdown" do
        user_private_messages_page.visit(user)

        expect(user_private_messages_page).to have_unread_icon_in_inbox_dropdown
      end

      it "shows unread count in inbox dropdown trigger and dropdown" do
        user.user_option.update!(sidebar_show_count_of_new_items: true)
        user_private_messages_page.visit(user)

        expect(user_private_messages_page).to have_unread_count_in_inbox_dropdown("(1)")
      end
    end
  end

  describe "on subfolder setup" do
    it "allows the user to view the default messages inbox" do
      set_subfolder "/forum"

      page.visit "/forum/u/#{user.username}/messages"
      expect(user_private_messages_page).to have_right_inbox_dropdown_value("Inbox")
    end
  end
end
