# frozen_string_literal: true

RSpec.describe "Viewing group members", type: :system do
  fab!(:group) { Fabricate(:group) }
  fab!(:user_in_group_1) { Fabricate(:user).tap { |u| group.add(u) } }
  fab!(:user_in_group_2) { Fabricate(:user).tap { |u| group.add(u) } }
  fab!(:user_in_group_3) { Fabricate(:user).tap { |u| group.add(u) } }

  it "loads more group members when a user scrolls to the bottom of the list" do
    stub_const(GroupsController, "MEMBERS_DEFAULT_PAGE_SIZE", 2) do
      visit("/g/#{group.name}/members")

      expect(page).to have_selector(".group-member", count: 3)
    end
  end
end
