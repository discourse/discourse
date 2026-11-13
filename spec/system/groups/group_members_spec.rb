# frozen_string_literal: true

describe "Group members" do
  with_select_controls(false)

  let(:group_page) { PageObjects::Pages::Group.new }

  fab!(:admin)
  fab!(:group)

  before { sign_in(admin) }

  describe "adds a user to the group" do
    it "shows that the user is already in the group" do
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

  context "with the new select controls" do
    with_select_controls(true)

    fab!(:user) { Fabricate(:user, username: "newmember") }

    it "adds the picked user to the group" do
      group_page.visit(group).add_users

      picker = PageObjects::Components::UiKit::DSelect.at(".modal-container .d-select.user-chooser")
      picker.search(user.username)
      picker.select_value(user.username)
      picker.close
      page.find(".modal-container button.add.btn-primary").click

      expect(page).to have_css(
        ".group-members .directory-table__cell--username.group-member .username",
        text: user.username,
      )
      expect(group.reload.users).to include(user)
    end
  end
end
