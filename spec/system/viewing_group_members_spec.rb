# frozen_string_literal: true

RSpec.describe "Viewing group members" do
  fab!(:group)
  fab!(:user_in_group_1) { Fabricate(:user).tap { |u| group.add(u) } }
  fab!(:user_in_group_2) { Fabricate(:user).tap { |u| group.add(u) } }
  fab!(:user_in_group_3) { Fabricate(:user).tap { |u| group.add(u) } }

  it "loads more group members when a user scrolls to the bottom of the list" do
    stub_const(GroupsController, "MEMBERS_DEFAULT_PAGE_SIZE", 2) do
      browser_page
        .goto("/g/#{group.name}/members")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator(".group-member").filter(visible: true)).to have_count(3)
    end
  end

  it "shows the owner badge to viewers who can't manage the group" do
    group.add_owner(user_in_group_1)
    sign_in(Fabricate(:user))

    browser_page
      .goto("/g/#{group.name}/members")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".directory-table__cell.group-owner").filter(visible: true),
    ).to contain_text([browser_text_pattern(I18n.t("js.groups.members.owner"))], useInnerText: true)
  end
end
