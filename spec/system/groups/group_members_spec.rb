# frozen_string_literal: true

describe "Group members", type: :system do
  let(:group_page) { PageObjects::Pages::Group.new }
  fab!(:admin)
  fab!(:group)

  before { sign_in(admin) }

  describe "adds a user to the group" do
    it "should show that the user is already in the group" do
      group_page.visit(group).add_users.select_user_and_add(admin)

      expect(
        group_page.find(".group-members .directory-table__cell--username.group-member .username"),
      ).to have_text(admin.username)

      group_page.add_users.select_user_and_add(admin)

      expect(page.find(".modal-container #modal-alert")).to have_text(
        "'#{admin.username}' is already a member of this group",
      )
    end
  end
end
