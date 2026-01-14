# frozen_string_literal: true

describe "Admin Users Page", type: :system do
  fab!(:current_user, :admin)
  fab!(:group_1) { Fabricate(:group, name: "group_a") }
  fab!(:group_2) { Fabricate(:group, name: "group_b") }
  fab!(:group_3) { Fabricate(:group, name: "group_c") }

  let(:admin_groups_page) { PageObjects::Pages::AdminGroups.new }

  before { sign_in(current_user) }

  it "shows list of active users and allows to filter" do
    admin_groups_page.visit

    expect(admin_groups_page).to have_groups(
      %w[
        admins
        group_a
        group_b
        group_c
        moderators
        staff
        trust_level_0
        trust_level_1
        trust_level_2
        trust_level_3
        trust_level_4
      ],
    )

    admin_groups_page.search("group")
    expect(admin_groups_page).to have_groups(%w[group_a group_b group_c])

    admin_groups_page.search("group_c")
    expect(admin_groups_page).to have_groups(%w[group_c])
  end
end
