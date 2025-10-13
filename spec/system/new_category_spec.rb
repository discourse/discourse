# frozen_string_literal: true

describe "New Category", type: :system do
  fab!(:admin)
  let(:category_page) { PageObjects::Pages::Category.new }

  before { sign_in(admin) }

  it "should create category with 0 in minimum_required_tags column when not defined" do
    category_page.visit_new_category

    category_page.find(".edit-category-tab-general input.category-name").fill_in(
      with: "New Category",
    )

    category_page.save_settings

    expect(page).to have_current_path("/c/new-category/edit/general")

    category = Category.find_by(name: "New Category")

    expect(category.minimum_required_tags).to eq(0)
  end
end
