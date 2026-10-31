# frozen_string_literal: true

describe "Category recipe migration details" do
  with_select_controls(true)

  fab!(:admin)
  fab!(:parent) { Fabricate(:category, name: "Growing") }
  fab!(:child) { Fabricate(:category, name: "Tomatoes", parent_category: parent) }

  it "searches lazy breadcrumbs after opening their button trigger" do
    SiteSetting.lazy_load_categories_groups = "admins"
    20.times { |index| Fabricate(:category, name: "Lazy category #{index}") }
    sign_in(admin)
    visit "/latest"

    picker = PageObjects::Components::UiKit::DSelect.at(".category-breadcrumb__category-selector")
    picker.open
    picker.search("Tomatoes")
    expect(picker).to have_option_value(child.id)
  end

  it "reaches every child of a long lazy level by scrolling" do
    SiteSetting.lazy_load_categories_groups = "admins"
    children = Fabricate.times(30, :category, parent_category: parent)
    sign_in(admin)
    visit parent.url

    picker =
      PageObjects::Components::UiKit::DSelect.at(".category-breadcrumb__subcategory-selector")
    picker.open
    size = page.find(picker.option_selector, match: :first)["aria-setsize"].to_i
    expect(size).to be >= children.size
    try_until_success do
      picker.scroll_listbox_to_bottom
      expect(page).to have_css("[role='option'][aria-posinset='#{size}']", wait: 0)
    end
    expect(page).to have_no_css(".d-select__footer")
  end
end
