# frozen_string_literal: true

describe "Filtering topics", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_query_filter) { PageObjects::Components::TopicQueryFilter.new }

  before { SiteSetting.experimental_topics_filter = true }

  context "when filtering with multiple filters" do
    fab!(:tag) { Fabricate(:tag, name: "tag1") }
    fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
    fab!(:topic) { Fabricate(:topic) }
    fab!(:closed_topic_with_tag) { Fabricate(:topic, closed: true, tags: [tag]) }

    it "should display the right topics when query string is `tags:tag1 status:closed`" do
      sign_in(user)

      visit("/filter")

      topic_query_filter.fill_in("tags:tag1 status:closed")

      expect(page).to have_current_path("/filter?status=closed&tags[]=tag1")
      expect(topic_list).to have_topics(count: 1)
      expect(topic_list).to have_topic(closed_topic_with_tag)
    end
  end

  context "when filtering by tags" do
    fab!(:tag) { Fabricate(:tag, name: "tag1") }
    fab!(:tag2) { Fabricate(:tag, name: "tag2") }
    fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
    fab!(:topic_with_tag2) { Fabricate(:topic, tags: [tag2]) }
    fab!(:topic_with_tag_and_tag2) { Fabricate(:topic, tags: [tag, tag2]) }

    it "should display the right topics when query string is `tags:tag1`" do
      sign_in(user)

      visit("/filter")

      topic_query_filter.fill_in("tags:tag1")

      expect(page).to have_current_path("/filter?tags[]=tag1")
      expect(topic_list).to have_topics(count: 2)
      expect(topic_list).to have_topic(topic_with_tag)
      expect(topic_list).to have_topic(topic_with_tag_and_tag2)
    end

    it "should display the right topics when query string is `tags:tag1+tag2`" do
      sign_in(user)

      visit("/filter")

      topic_query_filter.fill_in("tags:tag1+tag2")

      expect(page).to have_current_path("/filter?match_all_tags=true&tags[]=tag1&tags[]=tag2")
      expect(topic_list).to have_topics(count: 1)
      expect(topic_list).to have_topic(topic_with_tag_and_tag2)
    end

    it "should display the right topics when query string is `tags:tag1,tag2`" do
      sign_in(user)

      visit("/filter")

      topic_query_filter.fill_in("tags:tag1,tag2")

      expect(page).to have_current_path("/filter?match_all_tags=false&tags[]=tag1&tags[]=tag2")
      expect(topic_list).to have_topics(count: 3)
      expect(topic_list).to have_topic(topic_with_tag)
      expect(topic_list).to have_topic(topic_with_tag2)
      expect(topic_list).to have_topic(topic_with_tag_and_tag2)
    end

    it "should display the right topics when query string is `-tags:tag1+tag2`" do
      sign_in(user)

      visit("/filter")

      topic_query_filter.fill_in("-tags:tag1+tag2")

      expect(page).to have_current_path(
        "/filter?exclude_tags[]=tag1&exclude_tags[]=tag2&match_all_tags=true",
      )

      expect(topic_list).to have_topics(count: 2)
      expect(topic_list).to have_topic(topic_with_tag)
      expect(topic_list).to have_topic(topic_with_tag2)
    end

    it "should display the right topics when query string is `-tags:tag1,tag2`" do
      sign_in(user)

      visit("/filter")

      topic_query_filter.fill_in("-tags:tag1,tag2")

      expect(page).to have_current_path(
        "/filter?exclude_tags[]=tag1&exclude_tags[]=tag2&match_all_tags=false",
      )

      expect(topic_list).to be_empty
    end
  end

  context "when filtering by status" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:closed_topic) { Fabricate(:topic, closed: true) }

    it "should allow users to input a custom query string to filter through topics" do
      sign_in(user)

      visit("/filter")

      expect(topic_list).to have_topic(topic)
      expect(topic_list).to have_topic(closed_topic)

      topic_query_filter.fill_in("status:open")

      expect(topic_list).to have_topic(topic)
      expect(topic_list).to have_no_topic(closed_topic)
      expect(page).to have_current_path("/filter?status=open")

      topic_query_filter.fill_in("status:closed")

      expect(topic_list).to have_no_topic(topic)
      expect(topic_list).to have_topic(closed_topic)
      expect(page).to have_current_path("/filter?status=closed")
    end

    it "should filter topics when 'status' query params is present" do
      sign_in(user)

      visit("/filter?status=open")

      expect(topic_list).to have_topic(topic)
      expect(topic_list).to have_no_topic(closed_topic)
    end
  end
end
