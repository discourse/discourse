# frozen_string_literal: true

RSpec.describe "Viewing a category" do
  fab!(:category)
  fab!(:user)
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }

  before { SiteSetting.enable_unified_new = true }

  describe "when a new child category is created with a new category topic" do
    fab!(:child_category) { Fabricate(:category, parent_category: category) }

    fab!(:child_category_topic) do
      Fabricate(:topic, category: child_category).tap do |topic|
        child_category.update!(topic: topic)
      end
    end

    it "shows the category topic on the parent and child new lists when category definitions are shown" do
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

    it "shows the category topic only on the child new list when category definitions are hidden" do
      SiteSetting.show_category_definitions_in_topic_lists = false

      sign_in(user)

      category_page.visit(category)
      category_page.click_new

      expect(topic_list).to have_no_topic(child_category_topic)

      category_page.visit(child_category)
      category_page.click_new

      expect(topic_list).to have_topics(count: 1)
      expect(topic_list).to have_topic(child_category_topic)
    end
  end
end
