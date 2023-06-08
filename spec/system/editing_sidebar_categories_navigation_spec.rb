# frozen_string_literal: true

RSpec.describe "Editing sidebar categories navigation", type: :system do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group).tap { |g| g.add(user) } }
  fab!(:category) { Fabricate(:category) }
  fab!(:category_subcategory) { Fabricate(:category, parent_category_id: category.id) }
  fab!(:category_subcategory2) { Fabricate(:category, parent_category_id: category.id) }
  fab!(:category2) { Fabricate(:category) }
  fab!(:category2_subcategory) { Fabricate(:category, parent_category_id: category2.id) }

  let(:sidebar) { PageObjects::Components::Sidebar.new }

  before do
    SiteSetting.new_edit_sidebar_categories_tags_interface_groups = group.name
    SiteSetting.default_sidebar_categories = "#{category.id}|#{category2.id}"
    sign_in(user)
  end

  it "allows a user to edit the sidebar categories navigation" do
    visit "/latest"

    expect(sidebar).to have_categories_section

    modal = sidebar.click_edit_categories_button

    expect(modal).to have_right_title(I18n.t("js.sidebar.categories_form.title"))

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

  describe "when max_category_nesting has been set to 3" do
    before { SiteSetting.max_category_nesting = 3 }

    it "allows a user to edit sub-subcategories to be included in the sidebar categories section" do
      category_subcategory_subcategory =
        Fabricate(:category, parent_category_id: category_subcategory.id)

      category_subcategory_subcategory2 =
        Fabricate(:category, parent_category_id: category_subcategory.id)

      category2_subcategory_subcategory =
        Fabricate(:category, parent_category_id: category2_subcategory.id)

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
  end
end
