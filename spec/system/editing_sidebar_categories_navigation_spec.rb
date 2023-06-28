# frozen_string_literal: true

RSpec.describe "Editing sidebar categories navigation", type: :system do
  fab!(:user) { Fabricate(:user) }

  fab!(:category2) { Fabricate(:category, name: "category2") }

  fab!(:category2_subcategory) do
    Fabricate(:category, parent_category_id: category2.id, name: "category2 subcategory")
  end

  fab!(:category) { Fabricate(:category, name: "category") }

  fab!(:category_subcategory2) do
    Fabricate(:category, parent_category_id: category.id, name: "category subcategory 2")
  end

  fab!(:category_subcategory) do
    Fabricate(:category, parent_category_id: category.id, name: "category subcategory")
  end

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(user) }

  shared_examples "a user can edit the sidebar categories navigation" do |mobile|
    it "allows a user to edit the sidebar categories navigation", mobile: mobile do
      visit "/latest"

      sidebar.open_on_mobile if mobile

      expect(sidebar).to have_categories_section

      modal = sidebar.click_edit_categories_button

      expect(modal).to have_right_title(I18n.t("js.sidebar.categories_form_modal.title"))
      try_until_success { expect(modal).to have_focus_on_filter_input }
      expect(modal).to have_parent_category_color(category)
      expect(modal).to have_category_description_excerpt(category)
      expect(modal).to have_parent_category_color(category2)
      expect(modal).to have_category_description_excerpt(category2)
      expect(modal).to have_no_reset_to_defaults_button

      expect(modal).to have_categories(
        [category, category_subcategory, category_subcategory2, category2, category2_subcategory],
      )

      modal
        .toggle_category_checkbox(category)
        .toggle_category_checkbox(category_subcategory2)
        .toggle_category_checkbox(category2)
        .save

      expect(modal).to be_closed

      sidebar.open_on_mobile if mobile

      expect(sidebar).to have_section_link(category.name)
      expect(sidebar).to have_section_link(category_subcategory2.name)
      expect(sidebar).to have_section_link(category2.name)

      visit "/latest"

      sidebar.open_on_mobile if mobile

      expect(sidebar).to have_categories_section
      expect(sidebar).to have_section_link(category.name)
      expect(sidebar).to have_section_link(category_subcategory2.name)
      expect(sidebar).to have_section_link(category2.name)

      modal = sidebar.click_edit_categories_button
      modal.toggle_category_checkbox(category_subcategory2).toggle_category_checkbox(category2).save

      expect(modal).to be_closed

      sidebar.open_on_mobile if mobile

      expect(sidebar).to have_section_link(category.name)
      expect(sidebar).to have_no_section_link(category_subcategory2.name)
      expect(sidebar).to have_no_section_link(category2.name)
    end
  end

  describe "when on desktop" do
    include_examples "a user can edit the sidebar categories navigation", false
  end

  describe "when on mobile" do
    include_examples "a user can edit the sidebar categories navigation", true
  end

  it "displays the categories in the modal based on the fixed position of the category when `fixed_category_positions` site setting is enabled" do
    SiteSetting.fixed_category_positions = true

    visit "/latest"

    modal = sidebar.click_edit_categories_button

    expect(modal).to have_categories(
      [category2, category2_subcategory, category, category_subcategory2, category_subcategory],
    )
  end

  it "allows a user to deselect all categories in the modal" do
    Fabricate(:category_sidebar_section_link, linkable: category, user: user)
    Fabricate(:category_sidebar_section_link, linkable: category_subcategory2, user: user)

    visit "/latest"

    expect(sidebar).to have_categories_section

    modal = sidebar.click_edit_categories_button
    modal.deselect_all.save

    expect(sidebar).to have_section_link(category.name)
    expect(sidebar).to have_no_section_link(category_subcategory2.name)
    expect(sidebar).to have_section_link(category2.name)
    expect(sidebar).to have_section_link("Uncategorized")
  end

  it "allows a user to reset to the default navigation menu categories site setting" do
    Fabricate(:category_sidebar_section_link, linkable: category, user: user)
    Fabricate(:category_sidebar_section_link, linkable: category2, user: user)

    SiteSetting.default_navigation_menu_categories =
      "#{category_subcategory2.id}|#{category2_subcategory.id}"

    visit "/latest"

    expect(sidebar).to have_categories_section
    expect(sidebar).to have_section_link(category.name)
    expect(sidebar).to have_section_link(category2.name)

    modal = sidebar.click_edit_categories_button
    modal.click_reset_to_defaults_button.save

    expect(modal).to be_closed

    expect(sidebar).to have_no_section_link(category.name)
    expect(sidebar).to have_no_section_link(category2.name)
    expect(sidebar).to have_section_link(category_subcategory2.name)
    expect(sidebar).to have_section_link(category2_subcategory.name)
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

  it "allows a user to filter the categories in the modal by selection" do
    Fabricate(:category_sidebar_section_link, linkable: category_subcategory, user: user)
    Fabricate(:category_sidebar_section_link, linkable: category2, user: user)

    visit "/latest"

    expect(sidebar).to have_categories_section

    modal = sidebar.click_edit_categories_button
    modal.filter_by_selected

    expect(modal).to have_categories([category, category_subcategory, category2])
    expect(modal).to have_checkbox(category, disabled: true)
    expect(modal).to have_checkbox(category_subcategory)
    expect(modal).to have_checkbox(category2)

    modal.filter("category subcategory")

    expect(modal).to have_categories([category, category_subcategory])
    expect(modal).to have_checkbox(category, disabled: true)
    expect(modal).to have_checkbox(category_subcategory)

    modal.filter("").filter_by_unselected

    expect(modal).to have_categories(
      [category, category_subcategory2, category2, category2_subcategory],
    )

    expect(modal).to have_checkbox(category)
    expect(modal).to have_checkbox(category_subcategory2)
    expect(modal).to have_checkbox(category2, disabled: true)
    expect(modal).to have_checkbox(category2_subcategory)

    modal.filter_by_all

    expect(modal).to have_categories(
      [category, category_subcategory, category_subcategory2, category2, category2_subcategory],
    )

    expect(modal).to have_checkbox(category)
    expect(modal).to have_checkbox(category_subcategory)
    expect(modal).to have_checkbox(category_subcategory2)
    expect(modal).to have_checkbox(category2)
    expect(modal).to have_checkbox(category2_subcategory)
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

      expect(modal).to have_right_title(I18n.t("js.sidebar.categories_form_modal.title"))

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
