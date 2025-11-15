# frozen_string_literal: true

RSpec.describe "Categories Page" do
  fab!(:admin)
  fab!(:category)
  fab!(:subcategory) { Fabricate(:category, parent_category: category) }
  fab!(:topics) { Fabricate.times(3, :topic_with_op, category: subcategory) }
  let(:category_page) { PageObjects::Pages::Category.new }
  before { CategoryFeaturedTopic.feature_topics }

  describe "subcategories_with_featured_topics" do
    before { SiteSetting.desktop_category_page_style = "subcategories_with_featured_topics" }
    it "displays subcategories and topics" do
      category_page.visit_categories

      expect(page).to have_css(".badge-category[data-category-id='#{subcategory.id}']")
      topics.each do |t|
        expect(page).to have_css(".featured-topic[data-topic-id='#{t.id}']", text: t.title)
      end
    end
  end

  describe "with category and subcategory filters" do
    it "selected filters persist between route transitions" do
      sign_in(admin)
      category_page.visit(subcategory)

      category_selector =
        PageObjects::Components::SelectKit.new(".category-breadcrumb__category-selector")
      subcategory_selector =
        PageObjects::Components::SelectKit.new(".category-breadcrumb__subcategory-selector")
      expect(category_selector).to have_selected_name(category.name)
      expect(subcategory_selector).to have_selected_name(subcategory.name)

      category_page.visit_general(category, subcategory)
      category_page.back_to_category
      expect(category_selector).to have_selected_name(category.name)
      expect(subcategory_selector).to have_selected_name(subcategory.name)
    end
  end
end
