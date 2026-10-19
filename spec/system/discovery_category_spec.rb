# frozen_string_literal: true

describe "Discovery Category Routes" do
  fab!(:category) do
    Fabricate(:category, show_subcategory_list: true, subcategory_list_style: "boxes")
  end

  fab!(:subcategory1) { Fabricate(:category, parent_category: category) }
  fab!(:subcategory2) { Fabricate(:category, parent_category: category) }
  fab!(:subcategory3) { Fabricate(:category, parent_category: category) }

  let(:discovery) { PageObjects::Pages::Discovery.new }

  it "uses desktop_category_page style on categories and subcategories page" do
    browser_page.goto("/categories").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator(".category-list").filter(visible: true)).not_to have_count(0)

    browser_page
      .goto("/c/#{category.slug}/subcategories")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator(".category-list").filter(visible: true)).not_to have_count(0)
  end

  it "uses subcategory_list_style on category page" do
    browser_page.goto("/c/#{category.slug}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator(".category-boxes").filter(visible: true)).not_to have_count(0)

    browser_page
      .goto("/c/#{category.slug}/all")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator(".category-boxes").filter(visible: true)).not_to have_count(0)

    browser_page
      .goto("/c/#{category.slug}/none")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator(".category-boxes").filter(visible: true)).not_to have_count(0)
  end
end
