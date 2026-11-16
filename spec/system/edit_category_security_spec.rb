# frozen_string_literal: true

describe "Edit Category Security" do
  fab!(:current_user, :admin)
  fab!(:group)
  fab!(:category)
  fab!(:category_group_everyone) do
    Fabricate(
      :category_group,
      category: category,
      permission_type: CategoryGroup.permission_types[:full],
      group: Group.find(Group::AUTO_GROUPS[:everyone]),
    )
  end
  fab!(:category_group_1) do
    Fabricate(
      :category_group,
      category: category,
      permission_type: CategoryGroup.permission_types[:full],
      group: group,
    )
  end

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:category_permission_row) { PageObjects::Components::CategoryPermissionRow.new }

  before { sign_in(current_user) }

  it "lists the groups that can access the category" do
    category_page.visit_security(category)
    expect(category_page).to have_public_access_message
    expect(category_permission_row).to have_group_permission(
      category_group_1.group_name,
      %w[create reply],
    )
    expect(category_permission_row).to have_group_permission("everyone", %w[create reply])
  end

  it "can navigate to a group" do
    category_page.visit_security(category)
    category_permission_row.navigate_to_group(category_group_1.group.name)
    expect(page).to have_current_path("/g/#{category_group_1.group.name}")
  end

  it "can delete a group's permissions" do
    category_page.visit_security(category)
    category_permission_row.remove_group_permission(category_group_1.group.name)
    category_page.save_settings
    category_page.visit_security(category)
    expect(category_permission_row).to have_no_group_permission(category_group_1.group_name)
  end

  it "can modify a group's permissions" do
    category_group_everyone.update!(permission_type: CategoryGroup.permission_types[:reply])
    category_page.visit_security(category)
    category_permission_row.toggle_group_permission(category_group_1.group.name, "create")
    category_page.save_settings
    category_page.visit_security(category)
    expect(category_permission_row).to have_group_permission(category_group_1.group_name, %w[reply])
  end

  it "keeps logged-in permissions through edits and upcoming-change toggles" do
    form = PageObjects::Components::FormKit.new(".form-kit")
    category_page.visit_security(category)
    category_permission_row.remove_group_permission("everyone")
    category_permission_row.remove_group_permission(group.name)
    form.field("security_add_group_id").select(Group::AUTO_GROUPS[:logged_in_users])
    category_page.save_settings
    category_page.visit_security(category)
    expect(category_permission_row).to have_group_permission("logged_in_users")

    category_permission_row.toggle_group_permission("logged_in_users", "reply")
    category_page.save_settings
    category_page.visit_security(category)
    expect(category_permission_row).to have_group_permission("logged_in_users", %w[reply])

    SiteSetting.granular_anonymous_and_logged_in_groups_permissions = true
    category_page.visit_security(category)
    expect(category_permission_row).to have_group_permission("logged_in_users", %w[reply])
    category_permission_row.toggle_group_permission("logged_in_users", "create")
    category_page.save_settings
    category_page.visit_security(category)
    expect(category_permission_row).to have_group_permission("logged_in_users", %w[create reply])

    SiteSetting.granular_anonymous_and_logged_in_groups_permissions = false
    category_page.visit_general(category)
    form.field("name").fill_in("Renamed logged-in category")
    category_page.save_settings
    category_page.visit_security(category)
    expect(category_permission_row).to have_group_permission("logged_in_users", %w[create reply])
    expect(category_permission_row).to have_no_group_permission("everyone")
  end
end
