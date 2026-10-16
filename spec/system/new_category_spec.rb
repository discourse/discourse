# frozen_string_literal: true

describe "New Category" do
  fab!(:admin)
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:category_type_card) { PageObjects::Components::CategoryTypeCard.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }

  before { sign_in(admin) }

  it "keeps the action bar clear of the Powered by Discourse badge" do
    SiteSetting.enable_powered_by_discourse = true

    category_page.visit_new_category
    if URI.parse(browser_page.url).path == "/new-category/setup"
      category_type_card.find_type_card("discussion").click
    end
    form.field("name").fill_in("New Category")

    expect(category_page).to have_changes_banner
    expect(category_page).to have_powered_by_discourse
    expect(category_page.changes_banner_is_clear_of_powered_by_discourse?).to eq(true)
  end

  it "defaults minimum_required_tags to zero when creating a category" do
    category_page.visit_new_category

    browser_root
      .locator(".edit-category-tab-general input.category-name")
      .filter(visible: true)
      .fill("New Category")

    category_page.save_settings

    expect(browser_page).to have_url("/c/new-category/edit/general")

    category = Category.find_by(name: "New Category")

    expect(category.minimum_required_tags).to eq(0)
  end
end
