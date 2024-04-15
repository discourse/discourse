# frozen_string_literal: true

describe "Viewing user private messages", type: :system do
  fab!(:user) { Fabricate(:user, username: "mIxed_caSE_usERNAME") }
  fab!(:user2) { Fabricate(:user) }

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
  end

  describe "on subfolder setup" do
    it "allows the user to view the default messages inbox" do
      set_subfolder "/forum"

      page.visit "/forum/u/#{user.username}/messages"
      expect(user_private_messages_page).to have_right_inbox_dropdown_value("Inbox")
    end
  end
end
