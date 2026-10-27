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
    expect(picker.option_values.size).to eq(15)
    picker.search("Tomatoes")
    expect(picker).to have_option_value(child.id)
  end

  it "links a truncated child level to its parent's subcategories and closes the list" do
    SiteSetting.lazy_load_categories_groups = "admins"
    20.times { |index| Fabricate(:category, name: "Child #{index}", parent_category: parent) }
    sign_in(admin)
    visit parent.url

    picker =
      PageObjects::Components::UiKit::DSelect.at(".category-breadcrumb__subcategory-selector")
    picker.open
    expect(page).to have_css(
      ".d-select__footer",
      text: I18n.t("js.categories.plus_more_count", count: 6),
    )
    find(".d-select__footer a").click

    expect(page).to have_current_path("#{parent.url}/subcategories")
    expect(page).to have_no_css(".d-select__panel")
  end
end
