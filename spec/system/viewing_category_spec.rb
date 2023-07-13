# frozen_string_literal: true

RSpec.describe "Viewing a category", type: :system do
  fab!(:category) { Fabricate(:category) }
  fab!(:user) { Fabricate(:user) }
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }

  describe "when a new child category is created with a new category topic" do
    fab!(:child_category) { Fabricate(:category, parent_category: category) }

    fab!(:child_category_topic) do
      Fabricate(:topic, category: child_category).tap do |topic|
        child_category.update!(topic: topic)
      end
    end

    it "should show a new count on the parent and child category when 'show_category_definitions_in_topic_lists' is true" do
      SiteSetting.show_category_definitions_in_topic_lists = true

      sign_in(user)

      category_page.visit(category)
      category_page.click_new

      expect(topic_list).to have_topics(count: 1)
      expect(topic_list).to have_topic(child_category_topic)

      category_page.visit(child_category)
      category_page.click_new

      expect(topic_list).to have_topics(count: 1)
      expect(topic_list).to have_topic(child_category_topic)
    end

    it "should only show a new count on the child category when 'show_category_definitions_in_topic_lists' site setting is false" do
      SiteSetting.show_category_definitions_in_topic_lists = false

      sign_in(user)

      category_page.visit(category)

      expect(category_page).to have_no_new_topics

      category_page.visit(child_category)

      expect(category_page).to have_new_topics

      category_page.click_new

      expect(topic_list).to have_topics(count: 1)
      expect(topic_list).to have_topic(child_category_topic)
    end
  end
end
