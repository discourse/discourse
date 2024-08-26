# frozen_string_literal: true

describe "Edit Category Security", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
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
    )
  end

  let(:category_page) { PageObjects::Pages::Category.new }

  before { sign_in(current_user) }

  it "lists the groups that can access the catgory" do
    category_page.visit_security(category)
    expect(category_page).to have_public_access_message
    expect(category_page).to have_group(category_group_1.group_name)
    expect(category_page).to have_group("everyone")
  end

  it "can navigate to a group" do
  end

  it "can delete a group's permissions" do
  end

  it "can modify a group's permissions" do
    category_page.visit_security(category)
    expect(category_page).to have_no_public_access_message
  end
end
