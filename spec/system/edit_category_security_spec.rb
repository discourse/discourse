# frozen_string_literal: true

describe "Edit Category Security", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
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
end
