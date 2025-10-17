# frozen_string_literal: true

RSpec.describe "Categories Page" do
  fab!(:category)
  fab!(:subcategory) { Fabricate(:category, parent_category: category) }
  fab!(:topics) { Fabricate.times(3, :topic_with_op, category: subcategory) }
  before { CategoryFeaturedTopic.feature_topics }

  describe "subcategories_with_featured_topics" do
    before { SiteSetting.desktop_category_page_style = "subcategories_with_featured_topics" }
    it "displays subcategories and topics" do
      visit "/categories"

      expect(page).to have_css(".badge-category[data-category-id='#{subcategory.id}']")
      topics.each do |t|
        expect(page).to have_css(".featured-topic[data-topic-id='#{t.id}']", text: t.title)
      end
    end
  end
end
