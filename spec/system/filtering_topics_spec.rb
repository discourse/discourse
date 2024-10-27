# frozen_string_literal: true

describe "Filtering topics", type: :system do
  fab!(:user)
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_query_filter) { PageObjects::Components::TopicQueryFilter.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { SiteSetting.experimental_topics_filter = true }

  it "updates the input field when the query string is changed" do
    sidebar_section = Fabricate(:sidebar_section, user: user)

    sidebar_section_link_1 =
      Fabricate(
        :sidebar_section_link,
        sidebar_section: sidebar_section,
        linkable: Fabricate(:sidebar_url, name: "filter tags", value: "/filter?q=tag%3Atag1"),
      )

    sidebar_section_link_2 =
      Fabricate(
        :sidebar_section_link,
        sidebar_section: sidebar_section,
        linkable:
          Fabricate(
            :sidebar_url,
            name: "filter categories",
            value: "/filter?q=category%3Acategory1",
          ),
      )

    sign_in(user)

    visit("/latest")

    sidebar.click_section_link("filter tags")

    expect(topic_query_filter).to have_input_text("tag:tag1")

    sidebar.click_section_link("filter categories")

    expect(topic_query_filter).to have_input_text("category:category1")
  end

  describe "when filtering by status" do
    fab!(:topic) do
      topic = Fabricate(:topic, bumped_at: 1.day.ago)
      Fabricate(:post, topic: topic)
      topic
    end
    fab!(:closed_topic) do
      topic = Fabricate(:topic, closed: true)
      Fabricate(:post, topic: topic)
      topic
    end

    it "should display the right topics when the status filter is used in the query string" do
      sign_in(user)

      visit("/filter")

      expect(topic_list).to have_topic(topic)
      expect(topic_list).to have_topic(closed_topic)

      topic_list.visit_topic(closed_topic)
      expect(page).to have_current_path(closed_topic.url)

      send_keys("gj")

      expect(page).to have_current_path(topic.url)

      visit("/filter")
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

  describe "bulk topic selection" do
    fab!(:user) { Fabricate(:moderator) }

    it "shows the buttons and checkboxes" do
      topics = Fabricate.times(2, :topic)
      sign_in(user)
      visit("/filter")

      find("button.bulk-select").click
      expect(topic_list).to have_topic_checkbox(topics.first)
      expect(page).to have_no_css("button.bulk-select-topics-dropdown-trigger")

      topic_list.click_topic_checkbox(topics.first)
      expect(page).to have_css("button.bulk-select-topics-dropdown-trigger")
    end

    context "when on mobile", mobile: true do
      it "shows the buttons and checkboxes" do
        topics = Fabricate.times(2, :topic)
        sign_in(user)
        visit("/filter")

        find("button.bulk-select").click
        expect(topic_list).to have_topic_checkbox(topics.first)
        expect(page).to have_no_css("button.bulk-select-topics-dropdown-trigger")

        topic_list.click_topic_checkbox(topics.first)
        expect(page).to have_css("button.bulk-select-topics-dropdown-trigger")
      end
    end
  end
end
