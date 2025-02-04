# frozen_string_literal: true

describe "Discovery Category Routes", type: :system do
  fab!(:category) do
    Fabricate(:category, show_subcategory_list: true, subcategory_list_style: "boxes")
  end

  fab!(:subcategory1) { Fabricate(:category, parent_category: category) }
  fab!(:subcategory2) { Fabricate(:category, parent_category: category) }
  fab!(:subcategory3) { Fabricate(:category, parent_category: category) }

  let(:discovery) { PageObjects::Pages::Discovery.new }

  it "uses desktop_category_page style on categories and subcategories page" do
    visit "/categories"
    expect(page).to have_css(".category-list")

    visit "/c/#{category.slug}/subcategories"
    expect(page).to have_css(".category-list")
  end

  it "uses subcategory_list_style on category page" do
    visit "/c/#{category.slug}"
    expect(page).to have_css(".category-boxes")

    visit "/c/#{category.slug}/all"
    expect(page).to have_css(".category-boxes")

    visit "/c/#{category.slug}/none"
    expect(page).to have_css(".category-boxes")
  end
end
