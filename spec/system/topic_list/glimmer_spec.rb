# frozen_string_literal: true

describe "glimmer topic list", type: :system do
  fab!(:user)

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.experimental_glimmer_topic_list_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(user)
  end

  describe "/latest" do
    it "shows the list" do
      Fabricate.times(5, :topic)
      visit("/latest")

      expect(topic_list).to have_topics(count: 5)
    end
  end

  describe "/new" do
    it "shows the list and the toggle buttons" do
      SiteSetting.experimental_new_new_view_groups = Group::AUTO_GROUPS[:everyone]
      Fabricate(:topic)
      Fabricate(:new_reply_topic, current_user: user)

      visit("/new")

      expect(topic_list).to have_topics(count: 2)
      expect(page).to have_css(".topics-replies-toggle.--all")
      expect(page).to have_css(".topics-replies-toggle.--topics")
      expect(page).to have_css(".topics-replies-toggle.--replies")
    end
  end

  describe "categories-with-featured-topics page" do
    let(:category_list) { PageObjects::Components::CategoryList.new }

    it "shows the list" do
      SiteSetting.desktop_category_page_style = "categories_with_featured_topics"
      category = Fabricate(:category)
      topic = Fabricate(:topic, category: category)
      topic2 = Fabricate(:topic)
      CategoryFeaturedTopic.feature_topics

      visit("/categories")

      expect(category_list).to have_topic(topic)
      expect(category_list).to have_topic(topic2)
    end
  end

  describe "suggested topics" do
    it "shows the list" do
      topic1 = Fabricate(:post).topic
      topic2 = Fabricate(:post).topic
      new_reply = Fabricate(:new_reply_topic, current_user: user, count: 3)

      visit(topic1.relative_url)

      expect(topic_page).to have_suggested_topic(topic2)
      expect(page).to have_css("[data-topic-id='#{topic2.id}'] a.badge-notification.new-topic")

      expect(topic_page).to have_suggested_topic(new_reply)
      expect(
        find("[data-topic-id='#{new_reply.id}'] a.badge-notification.unread-posts").text,
      ).to eq("3")
    end
  end

  describe "topic highlighting" do
    # TODO: Those require `Capybara.disable_animation = false`

    skip "highlights newly received topics" do
      Fabricate(:read_topic, current_user: user)

      visit("/latest")

      new_topic = Fabricate(:post).topic
      TopicTrackingState.publish_new(new_topic)

      topic_list.had_new_topics_alert?
      topic_list.click_new_topics_alert

      topic_list.has_highlighted_topic?(new_topic)
    end

    skip "highlights the previous topic after navigation" do
      topic = Fabricate(:read_topic, current_user: user)

      visit("/latest")
      topic_list.visit_topic(topic)
      expect(topic_page).to have_topic_title(topic.title)
      page.go_back

      topic_list.has_highlighted_topic?(topic)
    end
  end

  describe "bulk topic selection" do
    fab!(:user) { Fabricate(:moderator) }

    it "shows the buttons and checkboxes" do
      topics = Fabricate.times(2, :topic)
      visit("/latest")

      find("button.bulk-select").click
      expect(topic_list).to have_topic_checkbox(topics.first)
      expect(page).to have_no_css("button.bulk-select-topics-dropdown-trigger")

      topic_list.click_topic_checkbox(topics.first)
      expect(page).to have_css("button.bulk-select-topics-dropdown-trigger")
    end

    context "when on mobile", mobile: true do
      it "shows the buttons and checkboxes" do
        topics = Fabricate.times(2, :topic)
        visit("/latest")

        find("button.bulk-select").click
        expect(topic_list).to have_topic_checkbox(topics.first)
        expect(page).to have_no_css("button.bulk-select-topics-dropdown-trigger")

        topic_list.click_topic_checkbox(topics.first)
        expect(page).to have_css("button.bulk-select-topics-dropdown-trigger")
      end
    end
  end

  it "unpins globally pinned topics on click" do
    topic = Fabricate(:topic, pinned_globally: true, pinned_at: Time.current)
    visit("/latest")

    expect(page).to have_css(".topic-list-item .d-icon-thumbtack:not(.unpinned)")

    find(".topic-list-item .d-icon-thumbtack").click
    expect(page).to have_css(".topic-list-item .d-icon-thumbtack.unpinned")

    wait_for { TopicUser.exists?(topic:, user:) }
    expect(TopicUser.find_by(topic:, user:).cleared_pinned_at).to_not be_nil
  end
end
