# frozen_string_literal: true

describe "Group members" do
  let(:group_page) { PageObjects::Pages::Group.new }

  fab!(:admin)
  fab!(:group)

  before { sign_in(admin) }

  describe "adds a user to the group" do
    it "shows that the user is already in the group" do
      group_page.visit(group).add_users.select_user_and_add(admin)

      expect(
        browser_root.locator(
          ".group-members .directory-table__cell--username.group-member .username",
        ).filter(visible: true),
      ).to PlaywrightMatchers.contain_text(browser_text_pattern(admin.username), useInnerText: true)

      group_page.add_users.select_user_and_add(admin)

      expect(
        browser_root.locator(".modal-container #modal-alert").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        browser_text_pattern("'#{admin.username}' is already a member of this group"),
        useInnerText: true,
      )
    end
  end
end
