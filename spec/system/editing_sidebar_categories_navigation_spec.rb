# frozen_string_literal: true

RSpec.describe "Editing sidebar categories navigation", type: :system do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group).tap { |g| g.add(user) } }
  fab!(:category) { Fabricate(:category, name: "category") }
  fab!(:category_subcategory) do
    Fabricate(:category, parent_category_id: category.id, name: "category subcategory")
  end

  fab!(:category_subcategory2) do
    Fabricate(:category, parent_category_id: category.id, name: "category subcategory 2")
  end

  fab!(:category2) { Fabricate(:category, name: "category2") }

  fab!(:category2_subcategory) do
    Fabricate(:category, parent_category_id: category2.id, name: "category2 subcategory")
  end

  let(:sidebar) { PageObjects::Components::Sidebar.new }

  before do
    SiteSetting.new_edit_sidebar_categories_tags_interface_groups = group.name
    SiteSetting.default_navigation_menu_categories = "#{category.id}|#{category2.id}"
    sign_in(user)
  end

  it "allows a user to edit the sidebar categories navigation" do
    visit "/latest"

    expect(sidebar).to have_categories_section

    modal = sidebar.click_edit_categories_button

    expect(modal).to have_right_title(I18n.t("js.sidebar.categories_form.title"))
    expect(modal).to have_parent_category_color(category)
    expect(modal).to have_category_description_excerpt(category)
    expect(modal).to have_parent_category_color(category2)
    expect(modal).to have_category_description_excerpt(category2)

    expect(modal).to have_categories(
      [category, category_subcategory, category_subcategory2, category2, category2_subcategory],
    )

    modal
      .toggle_category_checkbox(category)
      .toggle_category_checkbox(category_subcategory2)
      .toggle_category_checkbox(category2)
      .save

    expect(modal).to be_closed
    expect(sidebar).to have_section_link(category.name)
    expect(sidebar).to have_section_link(category_subcategory2.name)
    expect(sidebar).to have_section_link(category2.name)

    visit "/latest"

    expect(sidebar).to have_categories_section
    expect(sidebar).to have_section_link(category.name)
    expect(sidebar).to have_section_link(category_subcategory2.name)
    expect(sidebar).to have_section_link(category2.name)

    modal = sidebar.click_edit_categories_button
    modal.toggle_category_checkbox(category_subcategory2).toggle_category_checkbox(category2).save

    expect(modal).to be_closed

    expect(sidebar).to have_section_link(category.name)
    expect(sidebar).to have_no_section_link(category_subcategory2.name)
    expect(sidebar).to have_no_section_link(category2.name)
  end

  it "allows a user to filter the categories in the modal by the category's name" do
    visit "/latest"

    expect(sidebar).to have_categories_section

    modal = sidebar.click_edit_categories_button

    modal.filter("category subcategory 2")

    expect(modal).to have_categories([category, category_subcategory2])

    modal.filter("2")

    expect(modal).to have_categories(
      [category, category_subcategory2, category2, category2_subcategory],
    )

    modal.filter("someinvalidterm")

    expect(modal).to have_no_categories
  end

  describe "when max_category_nesting has been set to 3" do
    before_all { SiteSetting.max_category_nesting = 3 }

    fab!(:category_subcategory_subcategory) do
      Fabricate(
        :category,
        parent_category_id: category_subcategory.id,
        name: "category subcategory subcategory",
      )
    end

    fab!(:category_subcategory_subcategory2) do
      Fabricate(
        :category,
        parent_category_id: category_subcategory.id,
        name: "category subcategory subcategory 2",
      )
    end

    fab!(:category2_subcategory_subcategory) do
      Fabricate(
        :category,
        parent_category_id: category2_subcategory.id,
        name: "category2 subcategory subcategory",
      )
    end

    it "allows a user to edit sub-subcategories to be included in the sidebar categories section" do
      visit "/latest"

      expect(sidebar).to have_categories_section

      modal = sidebar.click_edit_categories_button

      expect(modal).to have_right_title(I18n.t("js.sidebar.categories_form.title"))

      modal
        .toggle_category_checkbox(category_subcategory_subcategory)
        .toggle_category_checkbox(category_subcategory_subcategory2)
        .toggle_category_checkbox(category2_subcategory_subcategory)
        .save

      expect(modal).to be_closed

      expect(sidebar).to have_section_link(category_subcategory_subcategory.name)
      expect(sidebar).to have_section_link(category_subcategory_subcategory2.name)
      expect(sidebar).to have_section_link(category2_subcategory_subcategory.name)
    end

    it "allows a user to filter the categories in the modal by the category's name" do
      visit "/latest"

      expect(sidebar).to have_categories_section

      modal = sidebar.click_edit_categories_button
      modal.filter("category2 subcategory subcategory")

      expect(modal).to have_categories(
        [category2, category2_subcategory, category2_subcategory_subcategory],
      )
    end
  end
end
