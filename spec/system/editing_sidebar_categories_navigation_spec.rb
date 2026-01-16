# frozen_string_literal: true

RSpec.describe "Editing sidebar categories navigation", type: :system do
  fab!(:user)

  fab!(:category2) { Fabricate(:category, name: "category 2") }

  fab!(:category2_subcategory) do
    Fabricate(:category, parent_category_id: category2.id, name: "category 2 subcategory")
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
      expect(modal).to have_focus_on_filter_input
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

    modal.filter("subcategory")

    expect(modal).to have_categories(
      [category, category_subcategory, category_subcategory2, category2, category2_subcategory],
    )

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

    modal.filter("category subcategory")

    expect(modal).to have_categories([category, category_subcategory])

    modal.filter("").filter_by_unselected

    expect(modal).to have_categories(
      [category, category_subcategory2, category2, category2_subcategory],
    )

    modal.filter_by_all

    expect(modal).to have_categories(
      [category, category_subcategory, category_subcategory2, category2, category2_subcategory],
    )
  end

  describe "hashtag decoration in category descriptions" do
    fab!(:tag) { Fabricate(:tag, name: "test-tag") }
    fab!(:icon_category) { Fabricate(:category, name: "icon category", icon: "wrench") }
    fab!(:emoji_category) { Fabricate(:category, name: "emoji category", emoji: "rocket") }

    fab!(:category_with_hashtags) do
      Fabricate(:category, name: "category with hashtags", description: <<~HTML)
          Discussion about
          and <a class="hashtag-cooked" href="/tag/#{tag.name}" data-type="tag" data-slug="#{tag.name}" data-id="#{tag.id}"><span class="hashtag-icon-placeholder"></span><span>#{tag.name}</span></a>
          and <a class="hashtag-cooked" href="/c/#{icon_category.slug}/#{icon_category.id}" data-type="category" data-slug="#{icon_category.slug}" data-id="#{icon_category.id}" data-style-type="icon" data-icon="wrench"><span class="hashtag-icon-placeholder"></span><span>#{icon_category.name}</span></a>
          and <a class="hashtag-cooked" href="/c/#{emoji_category.slug}/#{emoji_category.id}" data-type="category" data-slug="#{emoji_category.slug}" data-id="#{emoji_category.id}" data-style-type="emoji" data-emoji="rocket"><span class="hashtag-icon-placeholder"></span><span>#{emoji_category.name}</span></a>
        HTML
    end

    it "decorates hashtags for tags, icons and emojis in the description" do
      visit "/latest"

      expect(sidebar).to have_categories_section

      modal = sidebar.click_edit_categories_button

      expect(modal).to have_tag_in_description(category_with_hashtags)
      expect(modal).to have_icon_in_description(category_with_hashtags)
      expect(modal).to have_emoji_in_description(category_with_hashtags)
    end
  end

  describe "when max_category_nesting has been set to 3" do
    before_all { SiteSetting.max_category_nesting = 3 }

    before { SiteSetting.max_category_nesting = 3 }

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
        name: "category 2 subcategory subcategory",
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

      modal.filter("category 2 subcategory subcategory")

      expect(modal).to have_categories(
        [
          category,
          category_subcategory,
          category_subcategory_subcategory2,
          category_subcategory2,
          category2,
          category2_subcategory,
          category2_subcategory_subcategory,
        ],
      )
    end

    it "loads categories in multiple pages correctly" do
      resize_window(height: 500) do
        stub_const(CategoriesController, "MAX_CATEGORIES_LIMIT", 5) do
          visit "/latest"

          modal = sidebar.click_edit_categories_button

          expect(modal).to have_categories(
            [
              category,
              category_subcategory,
              category_subcategory_subcategory,
              category_subcategory_subcategory2,
              category_subcategory2,
            ],
          )

          modal.scroll_to_category(category_subcategory2)

          expect(modal).to have_categories(
            [
              category,
              category_subcategory,
              category_subcategory_subcategory,
              category_subcategory_subcategory2,
              category_subcategory2,
              category2,
              category2_subcategory,
              category2_subcategory_subcategory,
            ],
          )
        end
      end
    end
  end
end
