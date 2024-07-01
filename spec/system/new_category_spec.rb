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
    category_page.find(".edit-category-nav .edit-category-tags a").click
    category_page.focus_input(".edit-category-tab-tags #category-minimum-tags")
    category_page.save_settings

    expect(page).to have_current_path("/c/new-category/edit/general")
    # it was returning "PG::NotNullViolation: null value in column 'minimum_required_tags'" error
  end
end
