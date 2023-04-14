# frozen_string_literal: true

describe "Filtering topics", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_query_filter) { PageObjects::Components::TopicQueryFilter.new }

  before { SiteSetting.experimental_topics_filter = true }

  describe "when filtering by status" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:closed_topic) { Fabricate(:topic, closed: true) }

    it "should display the right topics when the status filter is used in the query string" do
      sign_in(user)

      visit("/filter")

      expect(topic_list).to have_topic(topic)
      expect(topic_list).to have_topic(closed_topic)

      topic_query_filter.fill_in("status:open")

      expect(topic_list).to have_topic(topic)
      expect(topic_list).to have_no_topic(closed_topic)

      topic_query_filter.fill_in("status:closed")

      expect(topic_list).to have_no_topic(topic)
      expect(topic_list).to have_topic(closed_topic)
    end
  end

  describe "when filtering by tags" do
    fab!(:tag) { Fabricate(:tag, name: "tag1") }
    fab!(:tag2) { Fabricate(:tag, name: "tag2") }
    fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
    fab!(:topic_with_tag2) { Fabricate(:topic, tags: [tag2]) }
    fab!(:topic_with_tag_and_tag2) { Fabricate(:topic, tags: [tag, tag2]) }

    it "should display the right topics when tags filter is used in the query string" do
      sign_in(user)

      visit("/filter")

      expect(topic_list).to have_topics(count: 3)
      expect(topic_list).to have_topic(topic_with_tag)
      expect(topic_list).to have_topic(topic_with_tag2)
      expect(topic_list).to have_topic(topic_with_tag_and_tag2)

      topic_query_filter.fill_in("tags:tag1")

      expect(topic_list).to have_topics(count: 2)
      expect(topic_list).to have_topic(topic_with_tag)
      expect(topic_list).to have_topic(topic_with_tag_and_tag2)
      expect(topic_list).to have_no_topic(topic_with_tag2)

      topic_query_filter.fill_in("tags:tag1+tag2")

      expect(topic_list).to have_topics(count: 1)
      expect(topic_list).to have_no_topic(topic_with_tag)
      expect(topic_list).to have_no_topic(topic_with_tag2)
      expect(topic_list).to have_topic(topic_with_tag_and_tag2)
    end
  end
end
